function processTree (){
  $("#nav_tree_form").ajaxSubmit({
    url: tree_url,
    type: "POST",
    dataType: "json",
    success: function(response){
      // First, remove any deleted items from the tree
      $.each(response.deleted, function(name, value){
          //FIXME: special case for other peoples smart pools
          //come up with better way or split out somewhere.

          //check if the li is the only one.  If so, remove its container as well
          if ($('#' + value.id).parent("li").siblings().size() === 0 ) {
            if($('#' + value.id).is(':visible')) {
              $('#' + value.id).parent("li").parent("ul").siblings("div").click();
            }
            $('#' + value.id).parent("li").parent("ul").remove();
          } else {
            if($('#' + value.id).is(':visible')) {
                $('#' + value.id).parent()
                .siblings('li:first')
                .children('div')
                .click();
              }
          }
          $('#' + value.id).parent().remove();
      });

      if(processRecursive) {
        $("#nav_tree").html(recursiveTreeTempl.process({"pools" : response.pools}));
        processRecursive = false;
      } else {
          // Loop through the items and decide if we need updated/new html for each item.
          processChildren(response.pools, treeItemTempl);
      }
    }
  });
}

function processChildren(list, templateObj){
/*  TODO: In future, we may need an additional state here of 'moved' which deletes
 *  the item where it was in the tree and adds it to its new parent.
*/
  $.each(list, function(n,data){
    var updatedNode;
    if(data.state === 'changed'){
      $('input[value^=' + data.id + '-]').attr('value', data.id + '-' + data.name);
      $('#' + data.id).html(data.name);
    } else if(data.state === 'new') {
        /* If the elem with id matching the parent id has a sibling that is a ul,
         * we should append the result of processing the template to the existing
         * sublist.  Otherwise, we need to add a new sublist and add it there.
        */
       var result  = templateObj.process(data);
       if ($('#' + data.parent_id).siblings('ul').size() > 0) {
         $('#' + data.parent_id).siblings('ul').append(result);
       } else {
         $('#' + data.parent_id).parent().append('<ul>' + result + '</ul>');
         $('#' + data.parent_id).siblings('span').addClass('expanded');
       }
      }
    else {
      if (data.children) {
          processChildren(data.children, templateObj);
      }
    }
  });
}

(function($){
	// widget prototype. Everything here is public
	var Tree  = {
                getTemplate: function () { return this.getData('template'); },
		setTemplate: function (x) {
                    this.setData('template', TrimPath.parseDOMTemplate(this.getData('template')));
		},
		init: function() {
                    this.setTemplate(this.getTemplate());
                    this.element.html(this.getTemplate().process(this.getData('content')));
                    var self = this;
                    this.element
                    .find('li:has(ul)')
                    .children('span.hitarea')
                    .click(function(event){
                      if (this == event.target) {
                          if($(this).siblings('ul').size() >0) {
                              if(self.getData('toggle') === 'toggle') {
                                  self.toggle(event, this);  //we need 'this' so we have the right element to toggle
                              } else {
                                self.element.triggerHandler('toggle',[event,this],self.getData('toggle'));
                              }
                          }
                      }
                    });
                    this.element
                    .find('li > div')
                    .filter(':not(.unclickable)')
                    .bind('click', function(event) {
                      if (this == event.target) {
                          if(self.getData('clickHandler') === 'clickHandler') {
                            self.clickHandler(event, this);  //we need 'this' so we have the right element to add click behavior to
                          } else {
                            self.element.triggerHandler('clickHandler',[event,this],self.getData('clickHandler'));
                          }
                      }
                    });
                    this.openToSelected(self);
                },
                toggle: function(e, elem) {
                    $(elem)
                      .toggleClass('expanded')
                      .toggleClass('expandable')
                      .siblings('ul').slideToggle("normal");
                },
                clickHandler: function(e,elem) {
                    // make this a default impl if needed.
                },
                openToSelected: function(self) {
                    //find 'selected' items and open tree accordingly.  This may need to have a
                    //marker of some sort passed in since different trees may have different needs.
                },
		off: function() {
			this.element.css({background: 'none'});
			this.destroy(); // use the predefined function
		}
	};
	$.yi = $.yi || {}; // create the namespace
	$.widget("yi.tree", Tree);
	$.yi.tree.defaults = {
            template: 'tree_template',
            toggle: 'toggle',
            clickHandler: 'clickHandler'
	};
})(jQuery);