$(function() {
	
	// メインコンテンツの横幅を取得して、Mapのサイズを指定
	var container_width = $('.container').width();
	$('#map').height(container_width);

	// Mapのサイズから、親のDiv要素のサイズを指定
	var map_height = $('#map').height();
	$('#map_div').height(map_height);
	
	$('#map[usemap]').rwdImageMaps();
});
