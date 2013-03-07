# ## Fondant v0.6.1
#
# The icing on the cake for user input. A simple jQuery HTML5 WYSIWYG editor
# using `contenteditable`.
#
#
# &copy; 2013 [Phillip Ridlen][1] & [Oven Bits, LLC][2]
#
#   [1]: http://phillipridlen.com
#   [2]: http://ovenbits.com

# ## Requirements
#
# * jQuery (tested with 1.9.1)
# * A modern-ish browser (IE9+)
#
# ## Usage
#
# ### Instantiation
#
# To launch the editor on a specific element:
#
#     $('div.editable').fondant();
#
# You can also use it on a `<textarea>` and it will convert it to a `<div>`
# while the editor is on:
#
#     $('form#content textarea.wysiwyg').fondant();
#
# ### Options Reference
#
# * `prefix` - prefix for all css classes and ids added to elements
#   generated by Fondant (default: `fondant`)
#
# * `toolbar` - If set to `true`, Fondant will generate a toolbar. If set to a function, Fondant
#   will use the return value of the function for the toolbar markup. If set to a string, Fondant
#   will use the string contents for the toolbar markup. If set to `false`, Fondant will not insert
#   a toolbar and you are responsible for building and wiring up your own.
#   (default: `true`)
#
# * `buttons` - An array of commands to include as buttons. Links & custom html cannot be
#   automatically addes as a toolbar button because there needs to be some form of input between
#   the button click and the application. Everything else is available to use.
#   (default: [ 'bold', 'italic', 'p', 'h1', 'h2', 'h3', 'h4', 'blockquote', 'ol', 'ul', 'indent',
#   'outdent', 'remove', 'unlink', 'undo', 'redo' ]`)
#


$ = jQuery

if typeof $ isnt 'undefined'

  # ## Class Definition
  #
  # Defines the `Fondant` class that will be instantiated when `$.fn.fondant`
  # is called.
  #
  class Fondant
    version: "0.6.1"

    # ## Methods

    constructor: (element, options) ->
      @init('fondant', element, options)

    # ### init( type, element, options )
    #
    # Initializes the Fondant editor.
    #
    # Parameters:
    #
    # * `type` - should always be 'fondant' (see constructor above)
    # * `element` - enable the Fondant editor for this element
    # * `options` - overrides for the default options
    # * `toolbar` -
    #
    init: (type, element, options) ->
      @id = new Date().getTime()
      @type = type
      @$element = $(element)
      @options = @getOptions(options)

      @templates.fondant = this

      if ( @$element.prop('tagName').toLowerCase() == 'textarea' )
        @textarea = @$element
        @replaceTextareaWithDiv()

      @makeEditable()
      @insertToolbar()
      @bindToolbar()

    # ### destroy( save = true )
    #
    # Destroy the Fondant editor and any elements created by it
    #
    destroy: ( keep_changes = true ) ->
      @unbindToolbar()
      @removeToolbar()
      @makeUneditable()
      @replaceDivWithTextarea(keep_changes) if @textarea
      @$element.removeData(@type)

    # ### focus()
    #
    # Focus the editor
    #
    focus: ->
      @$element.find('.' + @templates.editorContentClass()).focus()

    # ### insertToolbar()
    #
    # Add the formatting toolbar and bind the editor functions
    #
    insertToolbar: ->
      if @options.toolbar
        if typeof @options.toolbar is 'boolean'
          @$element.prepend(@templates.toolbar())
        else if typeof @options.toolbar is "string"
          @$element.prepend(@options.toolbar)
        else if typeof @options.toolbar is "function"
          @$element.prepend(@options.toolbar.call(@templates))

    # ### bindToolbar()
    #
    # Bind toolbar click events to their respective actions
    #
    bindToolbar: ->
      for action in @actions
        $button = $("##{ @type }-#{ @id } [data-action='#{ @type }-#{ action }']")
        $button.on 'click.fondant', { action: action, editor: this }, (event) ->
          event.preventDefault()
          event.data.editor[event.data.action]()

    # ### unbindToolbar()
    #
    # Remove all toolbar events. If the default Fondant toolbar was generated,
    # this is not needed since the DOM elements will be destroyed
    #
    unbindToolbar: ->
      $("##{ @type }-#{ @id } [data-action^='#{ @type }-']").off('.fondant') unless @options.toolbar

    # ### removeToolbar()
    #
    # Remove the formatting toolbar and unbind the editor functions.
    #
    removeToolbar: ->
      @$element.find(@options.prefix + "-toolbar").remove() if @options.toolbar

    # ### getElement()
    #
    # Get the actual underlying DOM (not jQuery) element
    #
    getElement: ->
      @$element.get(0)

    # ### getOptions( options )
    #
    # Get the options from the defaults, options passed to the constructor, and
    # the options set in the element's `data` attribute
    #
    getOptions: ( options ) ->
      options = $.extend {},
        $.fn[@type].defaults,  # default options
        options,               # options passed in to the constructor
        @$element.data()       # options set in the element's `data` attribute

    # ### getSelection()
    #
    # Grab the currently selected HTML content
    #
    getSelection: ->
      content = window
        .getSelection()
        .getRangeAt(0)
        .cloneContents()

      $('<span>').html(content).html()

    # ### value( html )
    #
    # Get the html from the editor, or if a value is passed in, set the html for the editor
    #
    value: ( html ) ->
      if html == undefined
        @$element.find('.' + @templates.editorContentClass()).html()
      else
        @$element.find('.' + @templates.editorContentClass()).html(html).html()

    # ### makeEditable()
    #
    # Make the element editable. If it is a `<textarea>`, convert it to a
    # `<div>` first.
    #
    makeEditable: ->
      @$element.attr 'contenteditable', 'true'
      @$element = @wrapEditorContent()

    # ### makeUneditable()
    #
    # Turns off `contenteditable` for this editor. If this editor was
    # originally a `<textarea>`, convert it back.
    #
    makeUneditable: ->
      @$element = @unwrapEditorContent()
      @$element.attr 'contenteditable', 'false'

    # ### replaceElement( $old, fresh )
    #
    # Replace a jQuery element with a new one from a string. Returns the new
    # jQuery element.
    #
    replaceElement: ( $old, fresh ) ->
      $old.replaceWith($fresh = $(fresh))
      $fresh

    # ### replaceDivWithTextarea( keep_changes = true )
    #
    # Swaps out the the `<div>` for a `<textarea>`, returning the original's
    # attributes. If keep_changes is false, put the original content back in.
    # Essentially reverses the process of `replaceTextareaWithDiv`.
    #
    replaceDivWithTextarea: ( keep_changes = true ) ->
      html = @$element.html()

      @$element = @replaceElement(@$element, @textarea)
      @$element.data(@type, this)
      @$element.val(html) if keep_changes

      @$element

    # ### replaceTextareaWithDiv()
    #
    # Swaps out the `<textarea>` with a `<div>` so we can use contenteditable.
    # Saves the `<textarea>`'s value and attributes so it can be restored when
    # the editor gets canceled/destroyed.
    #
    replaceTextareaWithDiv: ->
      if @textarea
        @$element = @replaceElement @$element, @templates.editorContent()
        @$element.data @type, this
        @$element.addClass(@textarea.attr('class'))
        @$element.html @textarea.val()

      @$element

    # ### unwrapEditorContent()
    #
    # Undoes what happens in `wrapEditorContent()`.
    #
    unwrapEditorContent: ->
      $wrap = @$element
      @$element = @replaceElement @$element, @$element.find(".#{ @templates.editorContentClass() }")
      @$element.data @type, this
      @$element.addClass @templates.editorClass()
      $wrap.remove()

      if @textarea
        @$element.addClass(@textarea.attr 'class')

      @$element

    # ### wrapEditorContent()
    #
    # Wraps the current `@$element` with another, outer `<div>` so we can insert the toolbar
    #
    wrapEditorContent: ->
      $original_element = @$element
      @$element = @$element.wrap(@templates.editor()).parent()
      @$element.data @type, this
      @$element.addClass($original_element.attr 'class').removeClass(@templates.editorContentClass())

      $original_element.removeClass @templates.editorClass()
      $original_element.removeData @type

      if @textarea
        $original_element.removeClass(@textarea.attr 'class')

      @$element

    # ### applyFormat( command, value )
    #
    # Applies a rich text editor command to selection or block. Available
    # commands are [listed on the MDN website][1].
    #
    #   [1]: https://developer.mozilla.org/en-US/docs/Rich-Text_Editing_in_Mozilla
    #
    applyFormat: ( command, value ) ->
      document.execCommand command, false, value
      @focus()

    # ## Formatting Functions
    #
    # This is where the magic happens.

    # ### actions
    #
    # Array of all the possible formatting actions to take
    #
    actions: [
      'remove', 'custom', 'undo', 'redo',
      'bold', 'italic',
      'p', 'h1', 'h2', 'h3', 'h4', 'blockquote',
      'ol', 'ul', 'indent', 'outdent',
      'link', 'unlink'
    ]

    # ### remove()
    #
    # Remove all formatting for selection
    #
    remove: -> @applyFormat 'removeFormat'

    # ### custom( html )
    #
    # For hooking in custom actions.
    #
    custom: (html) ->
      if navigator.appName == "Microsoft Internet Explorer"
        range = document.selection.createRange()
        range.pasteHTML(html)
      else
        @applyFormat 'insertHTML', html

    # ### Text Styles
    #
    # * `bold()`
    # * `italic()`
    bold:   -> @applyFormat 'bold'
    italic: -> @applyFormat 'italic'

    # ### Block Formats
    #
    # Wraps the selected element in a block element:
    #
    # * `p()`
    # * `h1()`
    # * `h2()`
    # * `h3()`
    # * `h4()`
    # * `blockquote()`
    #
    p:  -> @applyFormat 'outdent'; @applyFormat 'formatBlock', '<p>'
    h1: -> @applyFormat 'formatBlock', '<h1>'
    h2: -> @applyFormat 'formatBlock', '<h2>'
    h3: -> @applyFormat 'formatBlock', '<h3>'
    h4: -> @applyFormat 'formatBlock', '<h4>'
    blockquote: -> @applyFormat 'formatBlock', '<blockquote>'

    # ### Lists and Indentation
    #
    # * `ol()`
    # * `ul()`
    # * `indent()`
    # * `outdent()`
    #
    ol:       -> @applyFormat 'insertOrderedList'
    ul:       -> @applyFormat 'insertUnorderedList'
    indent:   -> @applyFormat 'indent'
    outdent:  -> @applyFormat 'outdent'

    # ### Links
    #
    # * `link( url )`
    # * `unlink()`
    link:   (url) -> @applyFormat 'createLink', url
    unlink:       -> @applyFormat 'unlink'

    # ## HTML Templates
    #
    # Templates for inserted html elements
    templates:

      editorClass: ->
        "#{ @fondant.options.prefix }-editor"
      editorContentClass: ->
        "#{ @editorClass() }-content"
      toolbarClass: ->
        "#{ @fondant.options.prefix }-toolbar"

      # ### templates.editor()
      #
      # Outer element to wrap the `contenteditable` region so we can insert the toolbar.
      #
      editor: ->
        id = "#{ @fondant.options.prefix }-#{ @fondant.id }"

        """
        <div class="#{ @editorClass() }" id="#{ id }">
        </div>
        """

      # ### templates.editorContent()
      #
      # If a `<textarea>` is being swapped out for a `<div>`, this is the
      # function we'll use to generate the editor.
      #
      editorContent: ->
        """
        <div class="#{ @editorClass()} #{ @editorContentClass() } contenteditable">
        </div>
        """

      # ### templates.toolbar()
      #
      toolbar: ->
        button = @toolbarClass() + '-button'
        html = """<ul class="#{ @toolbarClass() }">"""
        for action in @fondant.options.buttons
          html += """<li class="#{ button } #{ button }-#{ action }">"""
          html += """<a href="#" data-action="#{ @fondant.type }-#{ action }">#{ action }</a>"""
          html += """</li>"""
        html

  window.Fondant = Fondant

  # ## Plugin Setup
  #
  # ### jQuery function property
  #
  # Builds a fondant editor for each matched element.
  #
  $.fn.fondant = () ->
    option = arguments[0]
    args = Array.prototype.slice.call(arguments)[1..]

    if (typeof option == 'string' && args.length < 1)

      if option in ['getElement', 'getSelection', 'value']
        instance = $(this).data('fondant')
        if instance
          return instance[option].apply(instance, args)

    @map ->
      $this = $(this)
      instance = $this.data('fondant')
      options = typeof option == 'object' && option

      if (!instance)
        $this.data('fondant', (instance = new Fondant(this, options)))

      if typeof option == 'string'
        instance[option].apply(instance, args)

      instance.getElement()

  # ### Defaults
  #
  # Allows user to set their own defaults without having to pass in their
  # overrides on every instantiation
  #
  $.fn.fondant.defaults =
    prefix: 'fondant'
    toolbar: true
    buttons: [
      'bold', 'italic',
      'p', 'h1', 'h2', 'h3', 'h4', 'blockquote',
      'ol', 'ul', 'indent', 'outdent',
      'remove', 'unlink', 'undo', 'redo'
    ]

