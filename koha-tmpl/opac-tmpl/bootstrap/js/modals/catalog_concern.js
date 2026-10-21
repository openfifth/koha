$(document).ready(function () {
    // Detect that we were redirected here after login and re-open modal
    let urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has("modal")) {
        let modal = urlParams.get("modal");
        history.replaceState &&
            history.replaceState(
                null,
                "",
                location.pathname +
                    location.search
                        .replace(/[\?&]modal=[^&]+/, "")
                        .replace(/^&/, "?")
            );
        if (modal == "concern") {
            $("#addConcernModal").modal("show");
        }
    }

    $("#addConcernModal").on("show.bs.modal", function (e) {
        // Redirect to login modal if not logged in
        if (logged_in_user_id === "" && !Koha.prefs.OpacAnonCatalogConcerns) {
            $("#modalAuth").append(
                '<input type="hidden" name="return" value="' +
                    window.location.pathname +
                    window.location.search +
                    '&modal=concern" />'
            );
            $("#loginModal").modal("show");
            return false;
        }

        $("#addConfirm").prop("disabled", false);
        let concern_body = $("#concern_body");
        if (concern_body.val() === "") {
            let template = $("#concern_template").text();
            concern_body.val(template);
        }
    });

    $("#addConcernModal").on("click", "#addConfirm", function (e) {
        let reporter_email = $("#reporter_email").val();
        let concern_title = $("#concern_title").val();
        let concern_body = $("#concern_body").val();
        let biblio_id = $("#concern_biblio").val();

        params = {
            source: "catalog",
            reporter_email: reporter_email,
            title: concern_title,
            body: concern_body,
            biblio_id: biblio_id,
        };

        $("#concern-submit-spinner").show();
        $("#addConfirm").prop("disabled", true);
        $.ajax({
            url: "/api/v1/public/tickets",
            type: "POST",
            data: JSON.stringify(params),
            success: function (data) {
                $("#concern-submit-spinner").hide();
                $("#addConcernModal").modal("hide");
                $("#concern_body").val("");
                $("#concern_title").val("");
                $("#catalogue_detail_biblio").prepend(
                    '<div class="alert alert-success">' +
                        __("Your concern was successfully submitted.") +
                        "</div>"
                );
            },
            error: function (xhr) {
                $("#concern-submit-spinner").hide();
                $("#addConcernModal").modal("hide");

                let error_description = "";
                switch (xhr?.responseJSON?.error_code) {
                    case "anonymous_ticket_needs_email":
                        error_description = __(
                            "An email address must be included with anonymous tickets."
                        );
                        break;
                    case "email_not_allowed":
                        error_description = __(
                            "Anonymous tickets are not permitted from this email address."
                        );
                        break;
                    case "no_anonymous_tickets":
                        error_description = __(
                            "Anonymous tickets are not permitted."
                        );
                        break;
                }

                $("#catalogue_detail_biblio").prepend(
                    '<div class="alert alert-error">' +
                        __(
                            "There was an error when submitting your concern, please contact a librarian."
                        ) +
                        " " +
                        error_description +
                        "</div>"
                );
            },
            contentType: "json",
        });
    });
});
