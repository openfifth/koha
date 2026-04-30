<template>
    <div id="circ-nav-menu" class="sidebar_menu">
        <h5>{{ $__("Circulation") }}</h5>
        <ul>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/circulation.pl"
                    >{{ $__("Check out") }}</a
                >
            </li>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/returns.pl"
                    >{{ $__("Check in") }}</a
                >
            </li>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/renew.pl"
                    >{{ $__("Renew") }}</a
                >
            </li>
            <template v-if="superlibrarian || loggedinlibrary">
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/circ/set-library.pl"
                        >{{
                            usecirculationdesks
                                ? $__("Set library and desk")
                                : $__("Set library")
                        }}</a
                    >
                </li>
            </template>
            <template v-else-if="usecirculationdesks">
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/circ/set-library.pl"
                        >{{ $__("Set desk") }}</a
                    >
                </li>
            </template>
            <li v-if="fastcatalogingpref && fastcataloging">
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/cataloguing/addbiblio.pl?frameworkcode=FA"
                    >{{ $__("Fast cataloging") }}</a
                >
            </li>
            <li v-if="allowcheckoutnotes && managecheckoutnotes">
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/checkout-notes.pl"
                    >{{ $__("Checkout notes") }}</a
                >
            </li>
            <li v-if="onsitecheckouts">
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/on-site_checkouts.pl"
                    >{{ $__("Pending on-site checkouts") }}</a
                >
            </li>
        </ul>

        <h5>{{ $__("Holds") }}</h5>
        <ul>
            <li>
                <a :ref="el => templateRefs.push(el)" :href="holdsQueueUrl">{{
                    $__("Holds queue")
                }}</a>
            </li>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/pendingreserves.pl"
                    >{{ $__("Holds to pull") }}</a
                >
            </li>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/waitingreserves.pl"
                    >{{ $__("Holds awaiting pickup") }}</a
                >
            </li>
            <li v-if="curbsidepickup && managecurbsidepickups">
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/curbside_pickups.pl"
                    >{{ $__("Curbside pickups") }}</a
                >
            </li>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/reserveratios.pl"
                    >{{ $__("Hold ratios") }}</a
                >
            </li>
        </ul>

        <template v-if="userecalls && recalls">
            <h5>{{ $__("Recalls") }}</h5>
            <ul>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/recalls/recalls_queue.pl"
                        :title="$__('All active recalls')"
                        >{{ $__("Recalls queue") }}</a
                    >
                </li>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/recalls/recalls_to_pull.pl"
                        :title="
                            $__(
                                'Recalls that could be filled but have not been set waiting'
                            )
                        "
                        >{{ $__("Recalls to pull") }}</a
                    >
                </li>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/recalls/recalls_overdue.pl"
                        :title="
                            $__(
                                'Recalled items that are overdue to be returned'
                            )
                        "
                        >{{ $__("Overdue recalls") }}</a
                    >
                </li>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/recalls/recalls_waiting.pl"
                        :title="$__('Recalled items awaiting pickup')"
                        >{{ $__("Recalls awaiting pickup") }}</a
                    >
                </li>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/recalls/recalls_old_queue.pl"
                        :title="$__('Inactive recalls')"
                        >{{ $__("Old recalls") }}</a
                    >
                </li>
            </ul>
        </template>

        <template v-if="articlerequests">
            <h5>{{ $__("Patron request") }}</h5>
            <ul>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/circ/article-requests.pl"
                        >{{ $__("Article requests") }}</a
                    >
                </li>
            </ul>
        </template>

        <h5>{{ $__("Transfers") }}</h5>
        <ul>
            <li v-if="!independentbranchestransfers || superlibrarian">
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/branchtransfers.pl"
                    >{{ $__("Transfer") }}</a
                >
            </li>
            <li v-if="stockrotation">
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/transfers_to_send.pl"
                    >{{ $__("Transfers to send") }}</a
                >
            </li>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/circ/transferstoreceive.pl"
                    >{{ $__("Transfers to receive") }}</a
                >
            </li>
        </ul>

        <template v-if="overduesreport">
            <h5>{{ $__("Overdues") }}</h5>
            <ul>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/circ/overdue.pl"
                        :title="
                            $__(
                                'Warning: This report is very resource intensive on systems with large numbers of overdue items.'
                            )
                        "
                        >{{ $__("Overdues") }}</a
                    >
                </li>
                <li>
                    <a
                        :ref="el => templateRefs.push(el)"
                        href="/cgi-bin/koha/circ/branchoverdues.pl"
                        :title="
                            $__(
                                'Limited to your library. See report help for other details.'
                            )
                        "
                        >{{ $__("Overdues with fines") }}</a
                    >
                </li>
            </ul>
        </template>
    </div>
</template>

<script>
import { computed, onMounted, ref } from "vue";

export default {
    props: {
        superlibrarian: {
            type: Number,
        },
        loggedinlibrary: {
            type: Number,
        },
        usecirculationdesks: {
            type: Number,
        },
        fastcatalogingpref: {
            type: Number,
        },
        fastcataloging: {
            type: Number,
        },
        allowcheckoutnotes: {
            type: Number,
        },
        managecheckoutnotes: {
            type: Number,
        },
        onsitecheckouts: {
            type: Number,
        },
        useholdsqueuefilteroptions: {
            type: Number,
        },
        loggedinbranchcode: {
            type: String,
        },
        curbsidepickup: {
            type: Number,
        },
        managecurbsidepickups: {
            type: Number,
        },
        userecalls: {
            type: Number,
        },
        recalls: {
            type: Number,
        },
        articlerequests: {
            type: Number,
        },
        independentbranchestransfers: {
            type: Number,
        },
        stockrotation: {
            type: Number,
        },
        overduesreport: {
            type: Number,
        },
    },
    setup(props) {
        const templateRefs = ref([]);

        const holdsQueueUrl = computed(() => {
            const base = `/cgi-bin/koha/circ/view_holdsqueue.pl?branchlimit=${encodeURIComponent(props.loggedinbranchcode ?? "")}`;
            return props.useholdsqueuefilteroptions
                ? base
                : `${base}&run_report=1`;
        });

        onMounted(() => {
            const path = location.pathname.substring(1);

            templateRefs.value
                .find(a => a.href.includes(path))
                ?.classList.add("current");
        });

        return {
            templateRefs,
            holdsQueueUrl,
        };
    },
};
</script>

<style></style>
