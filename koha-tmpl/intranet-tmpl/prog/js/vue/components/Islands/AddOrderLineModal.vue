<template>
    <div
        :id="'addToBasket'"
        class="modal add_to_basket"
        tabindex="-1"
        role="dialog"
        :data-basketno="basketname"
        aria-hidden="true"
    >
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" :id="'addtoBasketLabel' + basketno">
                        {{ $__("Add order line") }}
                    </h1>
                    <button
                        type="button"
                        class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close"
                    ></button>
                </div>
                <div class="modal-body">
                    <fieldset class="acqui_basket_add">
                        <legend class="sr-only">
                            {{ $__("Add order line") }}
                        </legend>
                        <ul>
                            <li>
                                <form
                                    action="/cgi-bin/koha/catalogue/search.pl"
                                    method="get"
                                >
                                    <label
                                        >{{ $__("From an existing record") }}:
                                        <input type="text" name="q" size="25" />
                                    </label>
                                    <input
                                        type="submit"
                                        class="submit"
                                        id="searchtoorder"
                                        :data-booksellerid="vendorid"
                                        :data-basketno="basketno"
                                        value="Submit"
                                        @click="searchToOrder()"
                                    />
                                </form>
                            </li>
                            <li>
                                <a
                                    :href="`/cgi-bin/koha/acqui/newordersuggestion.pl?booksellerid=${vendorid}&amp;basketno=${basketno}`"
                                    >{{ $__("From a suggestion") }}</a
                                >
                            </li>
                            <li>
                                <a
                                    :href="`/cgi-bin/koha/acqui/newordersubscription.pl?booksellerid=${vendorid}&amp;basketno=${basketno}`"
                                    >{{ $__("From a subscription") }}</a
                                >
                            </li>
                            <li>
                                <a
                                    :href="`/cgi-bin/koha/acquisitions/order_management/orderlines/add`"
                                    >{{ $__("From a new (empty) record") }}</a
                                >
                            </li>
                            <li>
                                <a
                                    :href="`/cgi-bin/koha/acqui/duplicate_orders.pl?basketno=${basketno}`"
                                    >{{
                                        $__(
                                            "From an existing order line (copy)"
                                        )
                                    }}</a
                                >
                            </li>
                            <li>
                                <a
                                    :href="`/cgi-bin/koha/acqui/z3950_search.pl?booksellerid=${vendorid}&amp;basketno=${basketno}`"
                                    >{{
                                        $__(
                                            "From an external source (Z39.50/SRU)"
                                        )
                                    }}</a
                                >
                            </li>
                            <li v-if="stagemarcimport">
                                <a
                                    :href="`/cgi-bin/koha/tools/stage-marc-import.pl?basketno=${basketno}&amp;booksellerid=${vendorid}`"
                                >
                                    {{ $__("From a new file") }}</a
                                >
                            </li>
                            <li>
                                <a
                                    :href="`/cgi-bin/koha/acqui/addorderiso2709.pl?booksellerid=${vendorid}&amp;basketno=${basketno}`"
                                >
                                    {{ $__("From a staged file") }}</a
                                >
                            </li>
                            <li v-if="circulate">
                                <a
                                    :href="`/cgi-bin/koha/circ/reserveratios.pl?booksellerid=${vendorid}&amp;basketno=${basketno}`"
                                    >{{
                                        $__(
                                            "From titles with highest hold ratios"
                                        )
                                    }}</a
                                >
                            </li>
                            <li v-if="ermEnabled">
                                <a href="#">{{
                                    $__("From an ERM agreement")
                                }}</a>
                            </li>
                            <li>
                                <a
                                    href="/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
                                    >{{
                                        $__("Without a bibliographic record")
                                    }}</a
                                >
                            </li>
                        </ul>
                    </fieldset>
                </div>
                <div class="modal-footer">
                    <button
                        class="btn btn-default"
                        type="button"
                        data-bs-dismiss="modal"
                        @click="() => setCustomModal(null)"
                    >
                        {{ $__("Cancel") }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { inject } from "vue";
export default {
    props: {
        basketname: String,
        basketno: String,
        vendorid: String,
        stagemarcimport: String,
        circulate: String,
        erm: String,
        ermmodule: String,
    },
    setup(props) {
        const mainStore = inject("mainStore");
        const { setCustomModal } = mainStore;

        const ermEnabled = props.erm === "1" && props.ermmodule !== "0";

        function searchToOrder() {
            var date = new Date();
            var cookieData = "";
            date.setTime(date.getTime() + 10 * 60 * 1000);
            cookieData += props.basketno + "/" + props.vendorid;
            Cookies.set("searchToOrder", cookieData, {
                path: "/",
                expires: date,
                sameSite: "Lax",
            });
        }

        return {
            ermEnabled,
            setCustomModal,
            searchToOrder,
        };
    },
};
</script>

<style scoped></style>
