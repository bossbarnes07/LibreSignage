var SLIDE_INPUT = $('#slide-input');
var _selected_slide = "";

function slide_show(slide) {
	console.log("LibreSignage: Show slide '" + slide + "'");
	_selected_slide = slide;

	api_call(API_ENDP.SLIDE_GET, {'id': slide}, function(response) {
		if (!response || response.error) {
			console.log("LibreSignage: API error!");
			SLIDE_INPUT.val('');
			return;
		}
		SLIDE_INPUT.val(response.markup);
	});
}

function slide_rm() {
	if (!_selected_slide) {
		alert("Please select a slide to remove first.");
		return;
	}

	if (!confirm("Are you sure you want to delete the slide '" +
		_selected_slide + "'.")) {
		return;
	}

	api_call(API_ENDP.SLIDE_RM, {'id': _selected_slide},
						function(response) {
		if (!response || response.error) {
			console.log("LibreSignage: API error!");
			return;
		}

		$('#slide-btn-' + _selected_slide).remove();

		console.log("LibreSignage: Deleted slide '" +
				_selected_slide + "'.");
	});
}

function slide_mk() {
	console.log("LibreSignage: Create slide!");
}
