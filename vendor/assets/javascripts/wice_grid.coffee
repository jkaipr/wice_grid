setupHidingShowingOfFilterRow = (wiceGridContainer) ->
  hideFilter = '.wg-hide-filter'
  showFilter = '.wg-show-filter'
  filterRow = '.wg-filter-row'

  $(hideFilter, wiceGridContainer).click ->
    $(this).hide()
    $(showFilter, wiceGridContainer).show()
    $(filterRow, wiceGridContainer).hide()
    false

  $(showFilter, wiceGridContainer).click ->
    $(this).hide()
    $(hideFilter, wiceGridContainer).show()
    $(filterRow, wiceGridContainer).show()
    false

setupShowingAllRecords = (wiceGridContainer, gridProcessor) ->
  $('.wg-show-all-link, .wg-back-to-pagination-link', wiceGridContainer).click (event) ->
    event.preventDefault()
    gridState = $(this).data("grid-state")
    confirmationMessage = $(this).data("confim-message")
    reloadGrid = ->
      gridProcessor.reload_page_for_given_grid_state gridState
    if confirmationMessage
      if confirm(confirmationMessage)
        reloadGrid()
    else
      reloadGrid()



setupSubmitReset = (wiceGridContainer, gridProcessor) ->
  $('.submit', wiceGridContainer).click ->
    gridProcessor.process()
    false

  $('.reset', wiceGridContainer).click ->
    gridProcessor.reset()
    false

  $('.wg-filter-row input[type=text]', wiceGridContainer).keydown (event) ->
    if event.keyCode == 13
      event.preventDefault()
      gridProcessor.process()
      false

  $('.wg-external-submit-button').click (event) ->
    event.preventDefault()
    if gridName = $(this).data('grid-name')
      gridProcessor.process()
    false

  $('.wg-external-reset-button').click (event) ->
    event.preventDefault()
    if gridName = $(this).data('grid-name')
      gridProcessor.reset()
    false

  $('.wg-detached-filter').each (index, detachedFilterContainer) ->
    if gridName = $(this).data('grid-name')
      $('input[type=text]', this).keydown (event) ->
        if event.keyCode == 13
          event.preventDefault()
          gridProcessor.process()
          false



jQuery ->

  $(".wice-grid-container").each (index, wiceGridContainer) ->

    gridName = wiceGridContainer.id

    dataDiv = $(".wg-data", wiceGridContainer)

    processorInitializerArguments = dataDiv.data("processor-initializer-arguments")

    filterDeclarations = dataDiv.data("filter-declarations")

    grid = new WiceGridProcessor(gridName,
      processorInitializerArguments[0], processorInitializerArguments[1],
      processorInitializerArguments[2], processorInitializerArguments[3],
      processorInitializerArguments[4], processorInitializerArguments[5])

    for filterDeclaration in filterDeclarations
      do (filterDeclaration) ->

        grid.register
          filter_name : filterDeclaration.filter_name
          detached    : filterDeclaration.detached
          templates   : filterDeclaration.declaration.templates
          ids         : filterDeclaration.declaration.ids

    setupHidingShowingOfFilterRow wiceGridContainer
    setupSubmitReset wiceGridContainer, grid
    setupShowingAllRecords wiceGridContainer, grid

    window[gridName] = grid

#
#
#

WiceGridProcessor = (name, base_request_for_filter, base_link_for_show_all_records, link_for_export, parameter_name_for_query_loading, parameter_name_for_focus, environment) ->

  this.checkIfJsFrameworkIsLoaded =  ->
    if ! jQuery
      alert "jQuery not loaded, WiceGrid cannot proceed!"


  this.checkIfJsFrameworkIsLoaded()
  this.name = name
  this.parameter_name_for_query_loading = parameter_name_for_query_loading
  this.parameter_name_for_focus = parameter_name_for_focus
  this.base_request_for_filter = base_request_for_filter
  this.base_link_for_show_all_records = base_link_for_show_all_records
  this.link_for_export = link_for_export
  this.filter_declarations = new Array()
  this.environment = environment

  this.toString =  ->
    "<WiceGridProcessor instance for grid '" + this.name + "'>"


  this.process = (dom_id_to_focus)->
    window.location = this.build_url_with_params(dom_id_to_focus)


  this.set_process_timer = (dom_id_to_focus)->

    if this.timer
      clearTimeout(this.timer)
      this.timer = null

    processor = this

    this.timer = setTimeout(
      -> processor.process(dom_id_to_focus)
      1000
    )

  this.reload_page_for_given_grid_state = (grid_state)->
    request_path = this.grid_state_to_request(grid_state)
    window.location = this.append_to_url(this.base_link_for_show_all_records, request_path)


  this.load_query = (query_id)->
    request = this.append_to_url(
      this.build_url_with_params()
      this.parameter_name_for_query_loading +  encodeURIComponent(query_id)
    )

    window.location = request

  this.save_query = (field_id, query_name, base_path_to_query_controller, grid_state, input_ids)->
    if input_ids instanceof Array
      input_ids.each (dom_id) ->
        grid_state.push(['extra[' + dom_id + ']', $('#'+ dom_id)[0].value])


    request_path = this.grid_state_to_request(grid_state)

    jQuery.ajax
      url: base_path_to_query_controller
      async: true
      data: request_path + '&query_name=' + encodeURIComponent(query_name)
      dataType: 'script'
      success:  -> $('#' + field_id).val('')
      type: 'POST'

  this.grid_state_to_request = (grid_state)->
    jQuery.map(
      grid_state
      (pair) -> encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])
    ).join('&')


  this.append_to_url = (url, str)->

    sep = if url.indexOf('?') != -1
      if /[&\?]$/.exec(url)
        ''
      else
        '&'
    else
      '?'
    url + sep + str

  this.build_url_with_params = (dom_id_to_focus)->
    results = new Array()
    _this =  this
    jQuery.each(
      this.filter_declarations
      (i, filter_declaration)->
        param = _this.read_values_and_form_query_string(filter_declaration.filter_name, filter_declaration.detached, filter_declaration.templates, filter_declaration.ids)

        if param && param != ''
          results.push(param)
    )

    res = this.base_request_for_filter
    if  results.length != 0
      all_filter_params = results.join('&')
      res = this.append_to_url(res, all_filter_params)

    if dom_id_to_focus
      res = this.append_to_url(res, this.parameter_name_for_focus + dom_id_to_focus)

    res



  this.reset = ->
    window.location = this.base_request_for_filter


  this.export_to_csv = ->
    window.location = this.link_for_export


  this.register = (func)->
    this.filter_declarations.push(func)


  this.read_values_and_form_query_string = (filter_name, detached, templates, ids)->
    res = new Array()

    for i in [0 .. templates.length-1]

      if $(ids[i]) == null
        if this.environment == "development"
          message = 'WiceGrid: Error reading state of filter "' + filter_name + '". No DOM element with id "' + ids[i] + '" found.'
          if detached
            message += 'You have declared "' + filter_name + '" as a detached filter but have not output it anywhere in the template. Read documentation about detached filters.'

          alert(message);

        return ''

      el = $('#' + ids[i])

      if el[0] && el[0].type == 'checkbox'
        if el[0].checked
          val = 1;
      else
        val = el.val()

      if val instanceof Array
        for j in [0 .. val.length-1]
          if val[j] && val[j] != ""
            res.push(templates[i] + encodeURIComponent(val[j]))

      else if val &&  val != ''
        res.push(templates[i]  + encodeURIComponent(val));


    res.join('&');

  this


toggle_multi_select = (select_id, link_obj, expand_label, collapse_label)->
  select = $('#' + select_id)[0]
  if (select.multiple == true)
    select.multiple = false
    link_obj.title = expand_label
  else
    select.multiple = true
    link_obj.title = collapse_label

WiceGridProcessor._version = '3.2'

window['WiceGridProcessor'] = WiceGridProcessor