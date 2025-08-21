Temporary file - will replace AcquisitionsMenu once more of acquisitions has
been migrated

<template>
    <div id="acquisitions-menu" class="sidebar_menu">
        <h5>{{ $__("Acquisitions") }}</h5>
        <ul>
            <li>
                <a
                    :ref="el => templateRefs.push(el)"
                    href="/cgi-bin/koha/acquisitions"
                    >{{ $__("Acquisitions home") }}</a
                >
            </li>
            <li>
                <a
                    href="/cgi-bin/koha/acquisitions/fund_management"
                    :ref="el => templateRefs.push(el)"
                    >{{ $__("Fund management") }}</a
                >
            </li>
            <li>
                <a
                    href="/cgi-bin/koha/acquisitions/order_management"
                    :ref="el => templateRefs.push(el)"
                    >{{ $__("Order management") }}</a
                >
            </li>
        </ul>
    </div>
</template>

<script>
import { inject, onMounted, ref } from "vue";
import { storeToRefs } from "pinia";

export default {
    setup(props) {
        const navigationStore = inject("navigationStore");
        const { params } = storeToRefs(navigationStore);
        const acquisitionsStore = inject("acquisitionsStore");
        const { isUserPermitted } = acquisitionsStore;

        const templateRefs = ref([]);

        const removeTrailingSlash = str =>
            str.slice(-1) === "/" ? str.slice(0, -1) : str;

        onMounted(() => {
            const path = removeTrailingSlash(location.pathname.substring(1));

            templateRefs.value
                .find(a => removeTrailingSlash(a.href).includes(path))
                ?.classList.add("current");
        });
        return {
            isUserPermitted,
            params,
            templateRefs,
        };
    },
};
</script>

<style></style>
