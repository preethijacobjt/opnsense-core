<script>
    $( document ).ready(function() {
        let initial_load = true;
        let grid = '';
        var customRows = {};
        $('.nav-tabs a').each(function() {
            var tabId = $(this).attr('id').replace('_tab', '');
            grid = $("#grid-"+tabId).UIBootgrid({
                search:'/api/firewall/{{ruleController}}/search_rule/',
                get:'/api/firewall/{{ruleController}}/get_rule/',
                set:'/api/firewall/{{ruleController}}/set_rule/',
                add:'/api/firewall/{{ruleController}}/add_rule/',
                del:'/api/firewall/{{ruleController}}/del_rule/',
                toggle:'/api/firewall/{{ruleController}}/toggle_rule/',
                options:{
                    requestHandler: function(request){
                        if ( $('#category_filter_'+tabId).val().length > 0) {
                            request['category'] = $('#category_filter_'+tabId).val();
                        }
                        request['interface'] = tabId;
                        if ($('#inspect_checkbox_'+tabId).is(':checked')) {
                            request['inspect'] = true;
                        } else {
                            request['inspect'] = false;
                        }
                        return request;
                    },
                    responseHandler: function(response){
                        customRows['#grid-'+tabId] = response['rows'];
                        grid.data("customRows", customRows);
                        return response;
                    },
                    formatters: {
                        commands: function (column, row) {
                            let rowId = row.uuid;
                            let rule_type = row.rule_type;
                            if (rule_type && rule_type!=='interface') {
                                let ref = row["ref"] || "";
                                if (ref.trim().length > 0) {
                                    let url = `/${ref}`;
                                    return `
                                        <a href="${url}"
                                        class="btn btn-xs btn-default bootgrid-tooltip"
                                        title="{{ lang._('Lookup Rule') }}">
                                            <span class="fa fa-fw fa-search"></span>
                                        </a>
                                    `;
                                }
                                return "";
                            }

                            if (row.filter_rule) {
                                return `
                                    <button type="button" class="btn btn-xs btn-default command-move_before
                                        bootgrid-tooltip" data-row-id="${rowId}"
                                        title="{{ lang._('Move selected rule before this rule') }}">
                                        <span class="fa fa-fw fa-arrow-left"></span>
                                    </button>

                                    <button type="button" class="btn btn-xs btn-default command-delete
                                        bootgrid-tooltip" data-row-id="${rowId}"
                                        title="{{ lang._('Delete') }}">
                                        <span class="fa fa-fw fa-trash-o"></span>
                                    </button>
                                `;                               
                            }

                            return `
                                <button type="button" class="btn btn-xs btn-default command-move_before
                                    bootgrid-tooltip" data-row-id="${rowId}"
                                    title="{{ lang._('Move selected rule before this rule') }}">
                                    <span class="fa fa-fw fa-arrow-left"></span>
                                </button>

                                <button type="button" class="btn btn-xs btn-default command-edit
                                    bootgrid-tooltip" data-row-id="${rowId}"
                                    title="{{ lang._('Edit') }}">
                                    <span class="fa fa-fw fa-pencil"></span>
                                </button>

                                <button type="button" class="btn btn-xs btn-default command-copy
                                    bootgrid-tooltip" data-row-id="${rowId}"
                                    title="{{ lang._('Clone') }}">
                                    <span class="fa fa-fw fa-clone"></span>
                                </button>

                                <button type="button" class="btn btn-xs btn-default command-delete
                                    bootgrid-tooltip" data-row-id="${rowId}"
                                    title="{{ lang._('Delete') }}">
                                    <span class="fa fa-fw fa-trash-o"></span>
                                </button>
                            `;
                        }
                    }
                }
            });

            // move filter into action header
            $("#type_filter_container_"+tabId).detach().prependTo('#grid-'+tabId+'-header > .row > .actionBar > .actions');
            $("#category_filter_"+tabId).change(function(){
                $('#grid-'+tabId).bootgrid('reload');
            });
        });

        $(document).on("loaded.rs.jquery.bootgrid", "table[id^='grid-']", function(e) {
            grid = $(this);
            if(grid.data("customRows")) {
                tabId = grid.attr('id').replace('grid-', '');
                // reload categories before grid load
                ajaxCall('/api/firewall/{{ruleController}}/list_categories', {}, function(data, status){
                    if (data.rows !== undefined) {
                        $('select.category_filter').each(function() {
                            let filter = $(this);
                            let current_selection = filter.val();
                            filter.empty();
                            for (i=0; i < data.rows.length ; ++i) {
                                let row = data.rows[i];
                                let opt_val = $('<div/>').html(row.name).text();
                                let bgcolor = row.color != "" ? row.color : '31708f;'; // set category color
                                let option = $("<option/>").val(row.uuid).html(row.name);
                                if (row.used > 0) {
                                    option.attr(
                                    'data-content',
                                    "<span>"+opt_val + "</span>"+
                                    "<span style='background:#"+bgcolor+";' class='badge pull-right'>" + row.used + "</span>"
                                    );
                                    option.attr('id', row.uuid);
                                }

                                filter.append(option);
                            }
                            filter.val(current_selection);
                            filter.selectpicker('refresh');
                        });
                    }
                });

                let origin_texts = {
                    internal : 'Automatically generated rules',
                    floating: 'Floating rules',
                    group: 'Group rules',
                    internal2: 'Automatically generated rules (end of ruleset)',
                    automation: 'Rules from Automation'
                };

                let cus_rows = grid.data("customRows") || [];
                $.each(cus_rows, function (keys, rows) {
                    let tbody = $(keys + " tbody");
                    $.each(rows, function (index, value) {
                        let rule_type = value['rule_type'];
                        let uuid = value['uuid'];
                        if(rule_type && uuid) {
                            let $row = tbody.find(`tr[data-row-id='${uuid}']`);
                            if ($row.length > 0) {
                                $row.addClass(rule_type);
                            }
                        }
                    });
                    let uniqueRule = new Set(rows.map(row => row.rule_type).filter(rule => rule && rule !== 'interface'));
                    if (uniqueRule.size > 0) {
                        Array.from(uniqueRule).forEach(ruleType => {
                            tbody.find('.'+ruleType).hide();
                            let label = origin_texts[ruleType] || ruleType;
                            let colspanValue = $(keys+" tfoot tr td:first").attr("colspan");
                            colspanValue = parseInt(colspanValue) - 1;
                            let existingRow = tbody.find("#expand-" + ruleType + "-rules");
                            if (existingRow.length === 0) {
                                let rowHTML = `<tr id="expand-${ruleType}-rules" class="expand_type is_collapsed" data-type="${ruleType}">
                                    <td><i class="fa fa-folder-o text-muted"></i></td>
                                    <td colspan="${colspanValue}" style="text-align: end;">${label}</td>
                                    <td>
                                        <button class="btn btn-default btn-xs" id="expand-${ruleType}">
                                        <i class="fa fa-chevron-circle-down" aria-hidden="true"></i>
                                        <span class="badge">
                                            <span id="${ruleType}-rule-count"></span>
                                        </span>
                                        </button>
                                        <input id="${ruleType}-checkbox" type="checkbox" style="display: none;">
                                    </td>
                                </tr>`;
                                tbody.prepend(rowHTML);
                            } else {
                                let colspanTd = existingRow.find("td").eq(1);
                                colspanTd.attr("colspan", colspanValue);
                                colspanTd.html(label);
                            }
                        });
                    }

                    tbody.find('.expand_type button[id^="expand-"]').click(function() {
                        const btn = $(this);
                        const row = btn.closest('tr');
                        const rule = row.data('type');
                        var rule_checkbox = tbody.find('#'+rule+'-checkbox');
                        rule_checkbox.prop('checked', !rule_checkbox.prop('checked'));
                        if (rule_checkbox.is(':checked')) {
                            tbody.find('.'+rule).show();
                        } else {
                            tbody.find('.'+rule).hide();
                        }
                    });
                });
            }
        });

        // open edit dialog when opened with a uuid reference
        if (window.location.hash !== "" && window.location.hash.split("-").length >= 4) {
            grid.on('loaded.rs.jquery.bootgrid', function(){
                if (initial_load) {
                    $(".command-edit:eq(0)").clone(true).data('row-id', window.location.hash.substr(1)).click();
                    initial_load = false;
                }
            });
        }

        $("#reconfigureAct").SimpleActionButton();
        $("#savepointAct").SimpleActionButton({
            onAction: function(data, status){
                stdDialogInform(
                    "{{ lang._('Savepoint created') }}",
                    data['revision'],
                    "{{ lang._('Close') }}"
                );
            }
        });

        $("#revertAction").on('click', function(){
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_DEFAULT,
                title: "{{ lang._('Revert to savepoint') }}",
                message: "<p>{{ lang._('Enter a savepoint to rollback to.') }}</p>" +
                    '<div class="form-group" style="display: block;">' +
                    '<input id="revertToTime" type="text" class="form-control"/>' +
                    '<span class="error text-danger" id="revertToTimeError"></span>'+
                    '</div>',
                buttons: [{
                    label: "{{ lang._('Revert') }}",
                    cssClass: 'btn-primary',
                    action: function(dialogRef) {
                        ajaxCall("/api/firewall/{{ruleController}}/revert/" + $("#revertToTime").val(), {}, function (data, status) {
                            if (data.status !== "ok") {
                                $("#revertToTime").parent().addClass("has-error");
                                $("#revertToTimeError").html(data.status);
                            } else {
                                std_bootgrid_reload("grid-"+window.location.hash.slice(1));
                                dialogRef.close();
                            }
                        });
                    }
                }],
                onshown: function(dialogRef) {
                    $("#revertToTime").parent().removeClass("has-error");
                    $("#revertToTimeError").html("");
                    $("#revertToTime").val("");
                }
            });
        });

        // replace all "net" selectors with details retrieved from "list_network_select_options" endpoint
        ajaxGet('/api/firewall/{{ruleController}}/list_network_select_options', [], function(data, status){
            if (data.single) {
                $(".net_selector").each(function(){
                    $(this).replaceInputWithSelector(data, $(this).hasClass('net_selector_multi'));
                    /* enforce single selection when "single host or network" or "any" are selected */
                    if ($(this).hasClass('net_selector_multi')) {
                        $("select[for='" + $(this).attr('id') + "']").on('shown.bs.select', function(){
                            $(this).data('previousValue', $(this).val());
                        }).change(function(){
                            let prev = Array.isArray($(this).data('previousValue')) ? $(this).data('previousValue') : [];
                            let is_single = $(this).val().includes('') || $(this).val().includes('any');
                            let was_single = prev.includes('') || prev.includes('any');
                            let refresh = false;
                            if (was_single && is_single && $(this).val().length > 1) {
                                $(this).val($(this).val().filter(value => !prev.includes(value)));
                                refresh = true;
                            } else if (is_single && $(this).val().length > 1) {
                                if ($(this).val().includes('any') && !prev.includes('any')) {
                                    $(this).val('any');
                                } else{
                                    $(this).val('');
                                }
                                refresh = true;
                            }
                            if (refresh) {
                                $(this).selectpicker('refresh');
                                $(this).trigger('change');
                            }
                            $(this).data('previousValue', $(this).val());
                        });
                    }
                });
            }
        });

        // update history on tab state and implement navigation
        if (window.location.hash != "") {
            $('a[href="' + window.location.hash + '"]').click();
        } else {
            $('a[href="#floating"]').click();
        }
        
        $('.nav-tabs a').on('shown.bs.tab', function (e) {
            history.pushState(null, null, e.target.hash);
        });

        $(window).on('hashchange', function(e) {
            $('a[href="' + window.location.hash + '"]').click()
        });

        $('.inspect_checkbox').change(function() {
            const isChecked = $('#inspect_checkbox_'+window.location.hash.slice(1)).is(':checked');
            $('#grid-'+window.location.hash.slice(1)).bootgrid(isChecked ? "setColumns" : "unsetColumns", ['evaluations', 'states', 'packets', 'bytes']);
            $('#grid-'+window.location.hash.slice(1)).bootgrid(isChecked ? "unsetColumns" : "setColumns", ['protocol', 'source_net', 'source_port', 'destination_net', 'destination_port', 'gateway', 'schedule']);
            $('#grid-'+window.location.hash.slice(1)).bootgrid("reload");
        });

        $('button[id^="btn_inspect_"]').click(function() {
            let $checkbox = $('#inspect_checkbox_'+window.location.hash.slice(1));
            $checkbox.prop("checked", !$checkbox.prop("checked"));
            $(this).toggleClass('active btn-primary');
            $checkbox.trigger("change");
        });

        $(".protocol").change(function() {
            let icmp_type = $(".icmp_type").closest('tr');
            icmp_type.hide();
            let icmp6_type = $(".icmp6_type").closest('tr');
            icmp6_type.hide();
            if ($(".protocol").val()=='ICMP') {
                icmp_type.show();
            } else if ($(".protocol").val()=='IPV6-ICMP') {
                icmp6_type.show();
            }
        });
    });
</script>


<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
{% for tab in tabs %}
    <li><a data-toggle="tab" href="#{{tab['name']}}" id="{{tab['name']}}_tab">{{tab['caption']}}</a></li>
{% endfor %}
</ul>
<div class="tab-content content-box">
{% for tab in tabs %}
    <div id="{{tab['name']}}" class="tab-pane fade in active">
        <div class="hidden">
            <!-- filter per type container -->
            <div id="type_filter_container_{{tab['name']}}" class="btn-group">
                <button id="btn_inspect_{{tab['name']}}" class="btn btn-default">
                    <i class="fa fa-eye" aria-hidden="true"></i>
                    {{ lang._('Inspect') }}
                </button>
                <input id="inspect_checkbox_{{tab['name']}}" class="inspect_checkbox" type="checkbox" style="display: none;">
                <select id="category_filter_{{tab['name']}}" data-title="{{ lang._('Categories') }}" class="category_filter selectpicker" data-live-search="true" data-size="5"  multiple data-width="200px">
                </select>
            </div>
        </div>
        <!-- tab page "rules" -->
        <table id="grid-{{tab['name']}}" class="table table-condensed table-hover table-striped" data-editDialog="DialogFilterRule" data-editAlert="FilterRuleChangeMessage">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true"  data-visible="false">{{ lang._('ID') }}</th>
{% for fieldlist in gridFields %}
                    <th
                        data-column-id="{{fieldlist['id']}}"
                        data-class="{{fieldlist['class']|default('')}}"
                        data-width="{{fieldlist['width']|default('')}}"
                        data-type="{{fieldlist['type']|default('string')}}"
                        data-formatter="{{fieldlist['formatter']|default('')}}"
                        data-visible="{{fieldlist['visible']|default('')}}"
                    >{{fieldlist['heading']|default('')}}</th>
{% endfor %}
                    <th data-column-id="commands" data-width="9em" data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                </tr>
            </thead>
            <tbody>
            </tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
    </div>
{% endfor %}
</div>
<section class="page-content-main">
    <div class="content-box">
        <div class="col-md-12">
            <div id="FilterRuleChangeMessage" class="alert alert-info" style="display: none" role="alert">
                {{ lang._('After changing settings, please remember to apply them with the button below') }}
            </div>
            <hr/>
            <button class="btn btn-primary" id="reconfigureAct"
                    data-endpoint='/api/firewall/{{ruleController}}/apply'
                    data-label="{{ lang._('Apply') }}"
                    data-error-title="{{ lang._('Filter load error') }}"
                    type="button"
            ></button>
{% if SavePointBtns is defined %}
            <div class="pull-right">
                <button class="btn" id="savepointAct"
                        data-endpoint='/api/firewall/{{ruleController}}/savepoint'
                        data-label="{{ lang._('Savepoint') }}"
                        data-error-title="{{ lang._('snapshot error') }}"
                        type="button"
                ></button>
                <button  class="btn" id="revertAction">
                    {{ lang._('Revert') }}
                </button>
            </div>
{% endif %}
            <br/><br/>
        </div>
    </div>
</section>

{{ partial("layout_partials/base_dialog",['fields':formDialogFilterRule,'id':'DialogFilterRule','label':lang._('Edit rule')])}}