use strict;
use warnings;
use Config::Pit;

my $config = pit_get('MKWorld.com', require => {
	'database' => 'hoge',
	'username' => 'hogehoge',
	'password' => 'hogehogehoge',
	'consumer_key' => 'hogehogehogehoge',
	'consumer_secret' => 'hogehogehogehogehoge'
});

$config->{database} ||= $ENV{'DATABASE'};
$config->{username} ||= $ENV{'USERNAME'};
$config->{password} ||= $ENV{'PASSWORD'};
$config->{consumer_key} ||= $ENV{'CONSUMER_KEY'};
$config->{consumer_secret} ||= $ENV{'CONSUMER_SECRET'};

return {
	'DB' => {
		database => $config->{database},
		username => $config->{username},
		password => $config->{password}
	},
	Auth => {
		Twitter => {
			consumer_key => $config->{consumer_key},
			consumer_secret => $config->{consumer_secret}
		}
	}
};
