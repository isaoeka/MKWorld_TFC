// グローバル変数
var map;
var ctx;
var ctx2;

var MapPixels = new Array();
var PixelLength = 50;
var PixelSize;

var init = false;

// 初期化
function initialize() {
	
	// Mapを全て暗く設定
	for(var i=0; i<50; i++){
		MapPixels[i] = new Array();
		for(var j=0; j<50; j++){
			MapPixels[i][j] = 0;
		}
	}
	
	// 各要素の大きさを取得
	var screen = $(window).height();
	var header = $('.header').outerHeight();
	var footer = $('.footer').outerHeight();
	var content_current = $('.content').outerHeight() - $('.content').height();

	var content = screen - header - footer - content_current;

	$('#black_world').width($('.content').width());
	$('#black_world').height(Math.min($('.content').width()));
	$('.content').height(content);

	$('.content').offset({top: header, left: 0});

	// GoogleMap設定
	var latlng = new google.maps.LatLng(35.626446, 139.723444);
	var opts = {
		maxZoom: 15,
		minZoom: 15,
		zoom: 15,
		center: latlng,
		myTypeId: google.maps.MapTypeId.ROADMAP,
		disableDefaultUI: true
	};

	// MapとCanvasの大きさを調整
	var map_canvas = $('#map_canvas');
	$('#map_canvas').height(Math.min($('.content').width()));
	$('#map_canvas').width(Math.min($('.content').width()));
	map = new google.maps.Map(map_canvas[0], opts);
	
	var view = $('#view');
	$("#view").attr("height", Math.min($('.content').width()));
	$('#view').attr("width", Math.min($('.content').width()));
	
	var blocks = $('#blocks');
	$("#blocks").attr("height", Math.min($('.content').width()));
	$('#blocks').attr("width", Math.min($('.content').width()));

	// ブロック一つ分のサイズを計算
	PixelSize = $('#view').width() / PixelLength;
	
	// Canvasのコンテキストを取得
	ctx = view[0].getContext('2d');
	ctx2 = blocks[0].getContext('2d');

	// Canvasを透明に
	ctx.fillStyle = 'rgba(20, 20, 20, 0.7)';
	ctx.fillRect(0, 0, view.width(), view.height());
	ctx2.clearRect(0, 0, blocks.width(), blocks.height());

	// Mapに格子をかける
	squareBlock();

	// とりあえず現在位置を中心へ
	/*
	navigator.geolocation.getCurrentPosition(function(position) {
		var myLatlng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
		map.setCenter(myLatlng);
	});
	*/

	// googleMapがロードし終わったとき（移動やZoomでも発火する）
	google.maps.event.addListener(map, 'idle', function() {
		// 最初だけステージを初期化する
		if(!init) {
			stageInit();
			init = !init;
		}
	});
	
	// ポすると位置情報を取得して、その位置を中心に周りのブロックを明るくする
	// さらに位置情報をpo_historysに登録する
	$('#po_button').click( function(){
		navigator.geolocation.getCurrentPosition(function(position) {
			
			loading();

			var myLatlng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
	
			poAction(4, position.coords.latitude, position.coords.longitude);
			
			if(checkBounds(myLatlng)) {
				clearPixel(myLatlng);
				var percentage = percentageCalculation();
				$('#percentage').html(percentage + '%');
				percentageRegister(percentage);
			}
			else{
				loading();
			}

		}, null);
	});
	
	// マイページへのダイアログを表示する
	$('#mypage_button').click( function(){
		mypageDialog();
	});

	// ステージクリアする
	$('#clear_button').click( function(){
		clearGame();
	});
}

// ステージ初期化
function stageInit() {

	$.ajax({
		type: 'POST',
		url: '../position/get',
		dataType: 'json',
		success: function(res) {
			var len = res.length;
			for(var i=0; i<len; i++) {
				var myLatlng = new google.maps.LatLng(res[i].latitude, res[i].longitude);

				if(checkBounds(myLatlng)) {
					clearPixel(myLatlng);
					$('#percentage').html(percentageCalculation() + '%');
				}
			}
		}
	});
}

// DBに位置情報を登録する
function poAction(r, la, lo) {
	$.ajax({
		type: 'POST',
		url: '../position/register',
		data: { radius: r, latitude: la, longitude: lo },
		success: function(res) {

		}
	});
}

// DBにパーセンテージを登録する
function percentageRegister(p) {
	$.ajax({
		type: 'POST',
		url: '../user_worlds/register',
		data: { percentage: p },
		success: function(res) {
			loading();
		},
		error: function(res) {
			loading();   
		}
	});	
}

// 指定位置が画面内に存在するかチェックする
function checkBounds(latlng) {
	var latlngBounds = map.getBounds();
	var swLatlng = latlngBounds.getSouthWest();
	var neLatlng = latlngBounds.getNorthEast();

	if( latlng.lng() > swLatlng.lng() && latlng.lng() < neLatlng.lng() ) {
		if( latlng.lat() > swLatlng.lat() && latlng.lat() < neLatlng.lat() ) {
			return true;
		}
	}

	return false;
}

// 緯度経度をCanvasの座標に変換する
function coords2XY(latlng) {
	var latlngBounds = map.getBounds();
	var swLatlng = latlngBounds.getSouthWest();
	var neLatlng = latlngBounds.getNorthEast();

	var ratio_width = (neLatlng.lng() - latlng.lng()) / (neLatlng.lng() - swLatlng.lng());
	var ratio_height = (latlng.lat() - swLatlng.lat()) / (neLatlng.lat() - swLatlng.lat());
	
	return {x: $('#view').width()*ratio_width, y: $('#view').height()*ratio_height};
}

// Canvasの座標からどのブロックにあるか計算する
function XY2Pixel(x, y) {
	for(var i=0; i<50; i++) {
		for(var j=0; j<50; j++) {
			if(i*PixelSize < y && (i+1)*PixelSize >= y) {
				if(j*PixelSize < x && (j+1)*PixelSize >= x) {
					return {px: j, py: i};
				}
			}
		}
	}
	return {px: 0, py: 0};
}

// ブロックを「ぽ」する
function PoPixel(x, y) {
	searchPixel(x, y, 4);
}

function searchPixel(x, y, m) {
	
	if(x < 0 || x >= PixelLength || y < 0 || y >= PixelLength) return;
	if(MapPixels[y][x] == 0) {
		MapPixels[y][x] = 1;
		ctx.clearRect(x*PixelSize, y*PixelSize, PixelSize, PixelSize);
	}

	var _m = m - 1;
	if(_m == 0) return;

	searchPixel(x, y-1, _m);
	searchPixel(x-1, y, _m);
	searchPixel(x, y+1, _m);
	searchPixel(x+1, y, _m);
}

function clearPixel(latlng) {
	var xy1 = coords2XY(latlng);
	var xy2 = XY2Pixel(xy1.x, xy1.y);
	PoPixel(xy2.px, xy2.py);
}

// 格子状の線を描画する
function squareBlock() {

	for(var i=1; i<PixelLength; i++) {
		ctx2.beginPath();
		ctx2.strokeStyle = '#000000';
		ctx2.moveTo(0, i*PixelSize);
		ctx2.lineTo(PixelSize*PixelLength, i*PixelSize);
		ctx2.stroke();
		
		ctx2.beginPath();
		ctx2.strokeStyle = '#000000';
		ctx2.moveTo(i*PixelSize, 0);
		ctx2.lineTo(i*PixelSize, PixelSize*PixelLength);
		ctx2.stroke();
	}
}

// パーセンテージを計算する
function percentageCalculation() {
	var c = 0;
	
	for(var i=0; i<PixelLength; i++) {
		for(var j=0; j<PixelLength; j++) {
			if(MapPixels[i][j] == 1) c++;
		}
	}

	return ((c / (PixelLength*PixelLength)) * 100).toFixed(3);
}

// マイページへのダイアログを表示する
function mypageDialog() {
	var myRet = confirm('マイページに戻りますか？');
	if(myRet){
		window.location.href = '/';
	}
}

// ステージクリアする
function clearGame() {
	ctx.clearRect(0, 0, PixelSize*PixelLength, PixelSize*PixelLength);

	for(var i=0; i<PixelLength; i++) {
		for(var j=0; j<PixelLength; j++) {
			if(MapPixels[i][j] == 0) MapPixels[i][j] = 1;
		}
	}

	$('#percentage').html('100%');

	popup();
}

// 報酬のポップアップを表示する
function popup() {
	var shadow = $('<div>');
	shadow.css({
		position: 'absolute',
		width: $('.content').width(),
		height: $(window).height(),
		opacity: '0.6',
		background: '#000',
		zIndex: '1'
	});

	$('body').prepend(shadow);

	var info = $('<div class="opacity9 kadomaru">');
	info.css({
		position: 'absolute',
		width: $('.content').width() - $('.content').width()/10,
		height: $('.content').width() - $('.content').width()/10,
		left: '50%',
		top: '50%',
		marginLeft: '-' + ($('.content').width() - $('.content').width()/10)/2 + 'px',
		marginTop: '-' + ($('.content').width() - $('.content').width()/10)/2 + 'px',
		background: '#000',
		color: '#FFF',
		fontSize: '15px',
		border: '3px ridge #FFF',
		zIndex: '2'
	});

	var title = $('<div>');
	title.css({
		height: '10%',
		textAlign: 'center'
	});
	title.html('クリア報酬GET！');
	
	var imageDiv = $('<div>');
	imageDiv.css({
		height: '70%',
		textAlign: 'center'	
	});
	var image = $('<img>');
	image.css({
		width: info.width() - info.width()/3,
		height: info.width() - info.width()/3,
		left: '50%',
	});
	image.attr('alt', '報酬アイテム画像');
	image.attr('src', '../static/img/treasure.jpg');

	var actionDiv = $('<div>');
	actionDiv.css({
		height: '20%',
	});
	var mypageDiv = $('<div>');
	mypageDiv.css({
		float: 'left',
		width: '48%',
		textAlign: 'center'
	});
	var itemDiv = $('<div>');
	itemDiv.css({
		float: 'right',
		width: '48%',
		textAlign: 'center'
	});
	var mypage = $('<button>');
	mypage.css({
		margin: '5px'
	});
	mypage.attr('class', 'btn btn-primary');
	mypage.html('マイページ');
	mypage.click(function (){
		window.location.href = '/';
	});
	var item = $('<button>');
	item.css({
		margin: '5px'
	});
	item.attr('class', 'btn btn-primary');
	item.html('アイテム');
	item.click(function (){
		window.location.href = '/item';
	});

	mypageDiv.prepend(mypage);
	itemDiv.prepend(item);

	actionDiv.prepend(itemDiv);
	actionDiv.prepend(mypageDiv);

	imageDiv.prepend(image);

	info.prepend(actionDiv);
	info.prepend(imageDiv);
	info.prepend(title);

	$('body').prepend(info);
}

// loadingアニメーションを表示する
function loading() {
	
	if($('#shadow')[0]) {
		$('#shadow').remove();
		return;
	}

	var shadow = $('<div id="shadow">');
	shadow.css({
		position: 'absolute',
		width: $('.content').width(),
		height: $(window).height(),
		opacity: '0.6',
		background: '#000',
		zIndex: '1'
	});
	
	var gifDiv = $('<div>');
	gifDiv.css({
		position: 'absolute',
		left: '50%',
		top: '50%',
		marginLeft: '-' + (48 - 28/10)/2 + 'px',
		marginTop: '-' + (48 - 28/10)/2 + 'px'
	});
	var gif = $('<img>');
	gif.attr('src', '/static/img/loading.gif');

	gifDiv.prepend(gif);

	shadow.prepend(gifDiv);

	$('body').prepend(shadow);

}
