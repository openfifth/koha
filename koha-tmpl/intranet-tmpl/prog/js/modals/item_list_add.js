function showItemListAddModal() {
    $("#modal-item-list-add").modal("show");
    $("#modal-item-list-add-submit").removeAttr("disabled");
    $("#modal-item-list-add-submit-view").removeAttr("disabled");
}

$(document).ready(function () {
    $("#modal-item-list-add-form").validate({
        submitHandler: function (form, e) {
            $("#modal-item-list-add-submit").attr("disabled", "disabled");
            $("#modal-item-list-add-submit-view").attr("disabled", "disabled");

            const and_view =
                e.originalEvent.submitter.id ===
                "modal-item-list-add-submit-view";

            let itemnumbers = new Array();
            $("input[name='itemnumber'][type='checkbox']:checked").each(
                function () {
                    const itemnumber = $(this).val();
                    itemnumbers.push(itemnumber);
                }
            );

            $(".batch-op.itemnumber > .data-plain").each(function () {
                const itemnumber = $(this).text();
                itemnumbers.push(itemnumber);
            });

            if (itemnumbers.length == 0) {
                $("#modal-item-list-add").modal("hide");
                return;
            }

            const item_list_id = $("#item-list-add-form-select").val();
            const url = `/api/v1/item-lists/${item_list_id}/items`;

            var settings = {
                url: url,
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                data: JSON.stringify({
                    item_ids: itemnumbers,
                }),
            };

            $.ajax(settings)
                .done(function (response) {
                    $("#modal-item-list-add").modal("hide");
                    if (and_view) {
                        window.location.href =
                            "/cgi-bin/koha/lists/items/" + item_list_id;
                    }
                })
                .fail(function (err) {
                    var message =
                        err.responseJSON.error ||
                        err.responseJSON.errors.map(e => e.message).join("\n");
                    alert(message);
                });
        },
    });
});
