use strict;
use warnings;
use utf8;
use Amon2::Lite;

use Plack::Session;
use Plack::Session::Store::File;
use Plack::Session::State::Cookie;

use LWP::UserAgent;
use Net::Twitter;
use Digest::MD5 qw/md5_hex/;

use Text::Xslate;
use Log::Minimal;
$Log::Minimal::COLOR=1;

###########################################
#
# DB Sunny
#
use DBIx::Sunny;
sub db {
  my $self = shift;

  return $self->{db} ||= $self->get_dbh;
}

sub get_dbh {
  my $self = shift;

  my $config = $self->config;

  my $d = 'DBI:mysql:' . $config->{DB}{database};
  my $u = $config->{DB}{username};
  my $p = $config->{DB}{password};

  DBIx::Sunny->connect($d, $u, $p);
}



###########################################
#
# 称号を取得
#
sub get_shogo {
	my $self = shift;

	my $name = $self->session->get('name');

	my $db = $self->db;

	if($self->session->get('token')) {
		$name = '@' . $name;
	}

	my $query = 'SELECT shogo_id FROM users WHERE name = ?';
	my $user = $db->select_row($query, $name);

	$query = 'SELECT name FROM shogos WHERE id = ?';
	my $shogo = $db->select_row($query, $user->{shogo_id});

	$shogo->{name};
}



###########################################
#
# ユーザーのアイコン・名前・称号を取得
#
sub user_info {
	my $self = shift;

	my $config = $self->config;

	my $user_id   = $self->session->get('user_id');
	my $username  = $self->session->get('name');

	my $shogo = $self->get_shogo;

	#
	# Twitter
	#
	if($self->session->get('token')){

		my $token     = $self->session->get('token');
		my $token_s   = $self->session->get('token_secret');
		my $ck        = $config->{Auth}{Twitter}{consumer_key};
		my $cs        = $config->{Auth}{Twitter}{consumer_secret};

		my $nt = Net::Twitter->new(
			ssl => 1,
			traits              => [qw/API::RESTv1_1/],
			consumer_key        => $ck,
			consumer_secret     => $cs,
			access_token        => $token,
			access_token_secret => $token_s,
		);

		my $show_user = $nt->show_user( { id => $user_id} );
		my $icon      = $show_user->{profile_image_url_https};

		infof ddf $user_id;
		infof ddf $icon;

		# ログインできていることを確認するために、なんとなくセッションから情報をとる
		return {
			icon         => $icon                     || 'undefine',
			name         => $username                 || 'undefine',
			shogo        => $shogo                    || 'undefine',
		}

	} elsif($self->session->get('name')){
		#
		# 会員登録組
		#
		return {
			icon         => '../static/img/kari.jpg',
			name         => $username                 || 'undefine',
			shogo        => $shogo                    || 'undefine',
		}
	}
}


#############################################
#
# load plugins
#
__PACKAGE__->load_plugin('Web::JSON');
#__PACKAGE__->load_plugin('Web::CSRFDefender');
 __PACKAGE__->template_options(
   #syntax => 'Kolon',
   #header => ['header.tt'],
   #footer => ['footer.tt'],
);
__PACKAGE__->load_plugins(
  ## AuthのPlugin設定
  'Web::Auth' => +{
    module      => 'Twitter',
    on_finished => sub {
      my ($c, $access_token, $access_token_secret, $user_id, $screen_name) = @_;

      my $db = $c->db;

      my $isuser_q = "select name from users where name = ?";
      my $add_sname = '@'.$screen_name;
      if( !($db->select_row($isuser_q, $add_sname)) ){
        # DBにtwitterの情報を追加
        # TODO: なんかソルトっていうやつがあるらしい
        my $api_key = md5_hex( $screen_name . "salt" );
        my $query = "insert into users ( name, apikey, shogo_id, exp, twitter_id) values (?,?,?,?,?);";
        $db->query($query,'@'.$screen_name, $api_key, 1, 0, $user_id);
      }

      $c->session->set('token'               => $access_token);
      $c->session->set('token_secret'        => $access_token_secret);
      $c->session->set('user_id'             => $user_id);
      $c->session->set('name'                => $screen_name);

      return $c->redirect('/');
    },
  },
);
__PACKAGE__->enable_middleware(
  'Session' => (store => 'File')
);


###########################################
#
# ユーザー新規登録画面
#
get '/signup' => sub {
  my $c = shift;

  return $c->render('signup.tt');
};


###########################################
#
# ログイン画面
#
get '/login' => sub {
  my ($c) = @_;

  # とりあえずこぴぺですんません
  # twitterのトークン情報がある場合、マイページ表示
  if($c->session->get('user_id')){
    # ログインできていることを確認するために、なんとなくセッションから情報をとる
    return $c->render('index.tt',{
        user_id => $c->session->get('user_id') || 'undefine',
        name    => $c->session->get('name')    || 'undefine',
      });
  }

  return $c->render('login.tt')
};


############################################
#
# ログイン選択画面  -> user入力 or twitter
#
get '/login_select' => sub {
  my $c = shift;

  return $c->render('login_select.tt');
};


###########################################
#
# ログアウト画面
# ログアウトのときはセッションをきるためにExpire
get '/logout' => sub {
  my ($c) = @_;


  $c->session->expire;
  return $c->redirect('/');
};




###########################################
#
# マイページ
#
get '/' => sub {
	my $c = shift;

	# usernameがあれば、マイページ表示
	if($c->session->get('name')){
		my $user = $c->user_info;

		return $c->render('index.tt', {
			icon         => $user->{icon}             || 'undefine',
			name         => $user->{name}             || 'undefine',
			shogo        => $user->{shogo}            || 'undefine',
		});
	}

	#
	# リダイレクト
	#
	return $c->redirect('/login');
};



############################################
#
# ゲーム画面
#
any '/game' => sub {
	my $c = shift;

	#if(!($c->session->get('user_id')) || !$c->req->param('world_id') || !$c->req->param('stage_id')) {
	if(!$c->session->get('user_id')) {
		return $c->redirect('/');
	}

	#$c->session->set('world_id' => $c->req->param('world_id'));
	#$c->session->set('stage_id' => $c->req->param('stage_id'));

	$c->session->set('world_id' => 1 );
	$c->session->set('stage_id' => 1 );

    my $config = $c->config;

    my $user_id   = $c->session->get('user_id');
    my $username  = $c->session->get('name');

	my $db = $c->db;

	my $world_id = $c->session->get('world_id');
	my $stage_id = $c->session->get('stage_id');
	my $query = 'SELECT name FROM stages WHERE id = ? and world_id = ?';
	my $stage  = $db->select_row($query, $stage_id, $world_id);

	my $user = $c->user_info;

	return $c->render('game.tt', {
		icon         => $user->{icon}             || 'undefine',
		name         => $user->{name}             || 'undefine',
		shogo        => $user->{shogo}            || 'undefine',
		stage        => $stage->{name} . 'stage'  || 'undefine',
	});
};




############################################
#
# アイテム画面
#
get '/item' => sub {
	my $c = shift;

	my $user = $c->user_info;

	return $c->render('item.tt', {
		icon         => $user->{icon}             || 'undefine',
		name         => $user->{name}             || 'undefine',
		shogo        => $user->{shogo}            || 'undefine',
	});
};




############################################
#
# メニュー画面
#
get '/menu' => sub {
  my $c = shift;

	my $user = $c->user_info;

	return $c->render('menu.tt', {
		icon         => $user->{icon}             || 'undefine',
		name         => $user->{name}             || 'undefine',
		shogo        => $user->{shogo}            || 'undefine',
	});
};

###############################################
#
# ステージセレクト画面
#
get '/select'  => sub {
	my $c = shift;

	my $user = $c->user_info;

	return $c->render('select.tt',  { icon => $user->{icon}, name => $user->{name}, shogo => $user->{shogo} });
};

##############################################
#
# ステージ詳細画面
#
get '/stage'  => sub {
	my $c = shift;

	my $user = $c->user_info;

	return $c->render('stage.tt',  { icon => $user->{icon}, name => $user->{name}, shogo => $user->{shogo} });
};


#############################################
#
# ランキング画面
#
get '/ranking'  => sub {
	my $c = shift;

	my $db = $c->db;
	my $query = 'SELECT * FROM user_worlds ORDER BY map_percentage DESC LIMIT 10';
	my $ids = $db->select_all( $query );

  #infof ddf $ids->[0];
	$query = 'SELECT * FROM users WHERE id = ?';

	my @ranks;
  my $ranknum = 0;
	foreach (@$ids){
    #infof ddf $_;
    $ranknum++;
    my $row = $db->select_row( $query,  $_->{user_id});
    $row->{ranknum} = $ranknum;
    push @ranks, $row;
	};

	my $user = $c->user_info;

	return $c->render('ranking.tt',  { ranks => \@ranks,  ids => $ids , icon => $user->{icon}, name => $user->{name}, shogo => $user->{shogo} });
};

###########################################
#
# 各ステージのパーセンテージ登録
#
post '/user_worlds/register' => sub {
	my $c = shift;

	my $name        = $c->session->get('name');
	my $world_id    = $c->session->get('world_id');
	my $stage_id    = $c->session->get('stage_id');
	my $percentage  = $c->req->param('percentage');

	my $db = $c->db;

	if($c->session->get('token')) {
		$name = '@' . $name;
	}

	my $query = 'SELECT id FROM users WHERE name = ?';
	my $user  = $db->select_row($query, $name);

	my $user_id = $user->{id};

	$query = 'SELECT map_percentage FROM user_worlds WHERE user_id = ? and world_id = ? and stage_id = ?';
	if(!$db->select_row($query, $user_id, $world_id, $stage_id)) {
		$query = 'INSERT INTO user_worlds (user_id, world_id, stage_id, map_percentage) VALUES (?, ?, ?, ?)';
		$db->query($query, $user_id, $world_id, $stage_id, $percentage);
	}
	else {
		$query = 'UPDATE user_worlds SET map_percentage = ? WHERE user_id = ? and world_id = ? and stage_id = ?';
		$db->query($query, $percentage, $user_id, $world_id, $stage_id);
	}

	my $res = $c->render_json({ message => "success!" });
	$res->status(200);
	$res->content_type('application/json');
	return $res;
};



###########################################
#
# ユーザー位置情報登録
#
post '/position/register' => sub {
	my $c = shift;

	my $name       = $c->session->get('name');
	my $world_id   = $c->session->get('world_id');
	my $stage_id   = $c->session->get('stage_id');
	my $radius     = $c->req->param('radius');
	my $latitude   = $c->req->param('latitude');
	my $longitude  = $c->req->param('longitude');

	my $db = $c->db;

	if($c->session->get('token')) {
		$name = '@' . $name;
	}

	my $query = 'SELECT id FROM users WHERE name = ?';
	my $user  = $db->select_row($query, $name);

	my $user_id = $user->{id};

	$query = 'INSERT INTO po_historys (user_id, world_id, stage_id, radius, latitude, longitude) VALUES (?, ?, ?, ?, ?, ?);';
	$db->query($query, $user_id, $world_id, $stage_id, $radius, $latitude, $longitude);

	my $res = $c->render_json({ message => "success!" });
	$res->status(200);
	$res->content_type('application/json');
	return $res;
};



###########################################
#
# ユーザー位置情報取得
#
post '/position/get' => sub {
	my $c = shift;

	my $name     = $c->session->get('name');
	my $world_id = $c->session->get('world_id');
	my $stage_id = $c->session->get('stage_id');

	my $db = $c->db;

	if($c->session->get('token')) {
		$name = '@' . $name;
	}

	my $query = 'SELECT id FROM users WHERE name = ?';
	my $user  = $db->select_row($query, $name);

	my $user_id = $user->{id};

	$query = 'SELECT radius, latitude, longitude FROM po_historys WHERE user_id = ? and world_id = ? and stage_id = ?';
	my $position = $db->select_all($query, $user_id, $world_id, $stage_id);

	my $res = $c->render_json($position);
	$res->status(200);
	$res->content_type('application/json');
	return $res;
};



###########################################
#
# ユーザー登録
#
post '/user/register' => sub {
    my $c = shift;
    my $db = $c->db;

    my $name  = $c->req->param('username');
    my $pass  = $c->req->param('password');


    my $query = "select name from users where name = ?";
    my $name_row = $db->select_row($query, $name);
    infof ddf $name_row;
    if( $name_row ){
      return $c->render('signup.tt',{ 'validation'=>"ユーザー名が既に使われています<(_ _ )>"});
    }

    # ハッシュいれないとだめだお
    my $api_key = md5_hex( $name . $pass );

    $query = "insert into users ( name, apikey, shogo_id, exp) values (?,?,?,?);";
    $db->query($query, $name, $api_key, 1, 1);

    $c->session->set('user_id'             => $api_key);
    $c->session->set('name'                => $name);

    return $c->redirect('/');
};


###########################################
#
# ユーザーログイン
#
post '/login/user' => sub {
    my $c = shift;

    my $name  = $c->req->param('username');
    my $pass  = $c->req->param('password');

    # ハッシュいれないとだめだお
    my $api_key = md5_hex( $name . $pass );

    my $db = $c->db;

    my $query = "select id from users where name = ? and apikey = ?";
    # my $myapi = $db->select_one( $query,  $name );
    my $myid = $db->select_one( $query,  $name,  $api_key );

    # infof ddf $myapi;

    # return $c->redirect('/login_select');

    if( $myid gt 0 ) {
	    $c->session->set('user_id'             => $api_key);
	    $c->session->set('name'                => $name);

	    return $c->redirect('/');
    } else {
	    # $c->session->set('user_id'  => $api_key );
	    # $c->session->set('name'  => $name );

	    return $c->redirect('/login_select');
    };

};



############################################
#
# dev系
#
get '/dev/users' => sub {
  my $c  = shift;
  my $db = $c->db;

  my $query = 'select * from users';
  my $users = $db->select_all($query);

  return $c->render_json($users);
};

get '/dev/stages' => sub {
  my $c  = shift;
  my $db = $c->db;

  my $query = 'select * from stages';
  my $users = $db->select_all($query);

  return $c->render_json($users);
};

get '/dev/worlds' => sub {
  my $c  = shift;
  my $db = $c->db;

  my $query = 'select * from worlds';
  my $users = $db->select_all($query);

  return $c->render_json($users);
};

get '/dev/shogos' => sub {
  my $c  = shift;
  my $db = $c->db;

  my $query = 'select * from shogos';
  my $users = $db->select_all($query);

  return $c->render_json($users);
};







__PACKAGE__->to_app(handle_static => 1);



