$(document).ready(function() {

	// Open external links in a new window
	hostname = window.location.hostname
	$("a[href^=http]")
	  .not("a[href*='" + hostname + "']")
	  .addClass('link external')
	  .attr('target', '_blank');
	
	$('.showHide.code_toggle').click(function(){
		$(this).parent().find('.code').toggle()
	});
	$('.showHide.token_toggle').click(function(){
		$(this).parent().find('.tokens').toggle()
	});
	
	Tipped.create('.tip', { skin: 'white', hook: { target:  'bottomleft', tooltip: 'topleft' } });

});
