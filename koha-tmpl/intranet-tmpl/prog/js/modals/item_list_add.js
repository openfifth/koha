function showItemListAddModal() {
    $("#modal-item-list-add").modal("show");
    $("#modal-item-list-add-submit").removeAttr("disabled");
}

$(document).ready(function () {
    $("#modal-item-list-add-form").validate({
        submitHandler: function (form) {
            $("#modal-item-list-add-submit").attr("disabled", "disabled");

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
