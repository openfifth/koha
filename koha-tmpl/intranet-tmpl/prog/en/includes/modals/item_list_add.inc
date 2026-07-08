<div class="modal" id="modal-item-list-add" tabindex="-1" role="dialog" aria-labelledby="modal-item-list-add-label">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h1 class="modal-title" id="modal-item-list-add-label">Add items to item list</h1>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form method="get" id="modal-item-list-add-form">
                <div class="modal-body">
                    <fieldset>
                        <p>
                            <label for="item-list-add-form-select" class="required">Item list: </label>
                            <select name="item_list" id="item-list-add-form-select">
                                [% FOREACH list IN item_lists %]
                                    <option value="[% list.id | html %]">[% list.name | html %]</option>
                                [% END %]
                            </select>
                            <span class="required">Required</span>
                        </p>
                    </fieldset>
                </div>
                <div class="modal-footer">
                    <button id="modal-item-list-add-submit" class="btn btn-primary">Add to list</button>
                    <button type="button" class="btn btn-default" data-bs-dismiss="modal">Cancel</button>
                </div>
            </form>
        </div>
        <!-- /.modal-content -->
    </div>
    <!-- /.modal-dialog -->
</div>
<!-- /#modal-item-list-add.modal -->
