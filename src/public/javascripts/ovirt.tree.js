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
          if($('#' + value.id).hasClass('SmartPool')) {
            if($("#smart_nav_tree > li > div.SmartPool").size() > 1) {
                $("#smart_nav_tree > li:first div").click();
            } else {
              $('#nav_tree > li:first > div').click();
            }
          } else {
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
          }
          $('#' + value.id).parent().remove();
      });

      if(processRecursive) {
        $("#nav_tree").html(recursiveTreeTempl.process({"pools" : response.pools}));
        $("#smart_nav_tree").html(recursiveTreeTempl.process({"pools" : response.smart_pools}));
        processRecursive = false;
      } else {
          // Loop through the items and decide if we need updated/new html for each item.
          processChildren(response.pools, treeItemTempl);
          processChildren(response.smart_pools, treeItemTempl);
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
         if (data.type === "SmartPool"){  //handle current user smart pools
           if($('#smart_nav_tree > li:has(ul)').size() > 0) {
             $(result).insertBefore('#smart_nav_tree > li:has(ul):first');
           } else {
             $('#smart_nav_tree').append(result);
           }
         } else {
           $('#' + data.parent_id).parent().append('<ul>' + result + '</ul>');
           $('#' + data.parent_id).siblings('span').addClass('expanded');
         }
       }
      }
    else {
      if (data.children) {
          processChildren(data.children, templateObj);
      }
    }
  });
}