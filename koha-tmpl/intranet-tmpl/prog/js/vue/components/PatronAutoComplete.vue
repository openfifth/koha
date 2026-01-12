<template>
    <input type="text" ref="searchInputRef" :placeholder="placeholder" />
    <span id="patronautocomplete_selection"></span>
</template>

<script>
import { ref, onMounted } from "vue";

export default {
    props: {
        id: String,
        placeholder: String,
        patronAutoCompleteOptions: Object,
    },
    setup(props) {
        const searchInputRef = ref(null);

        onMounted(() => {
            const $el = $(searchInputRef.value);
            window.patron_autocomplete($el, {
                "on-select-add-to": {
                    container: $("#patronautocomplete_selection"),
                    input_name: props.id,
                },
                "on-select-callback": function (event, ui) {
                    $el.val("").focus();
                    $el.hide();
                    return false;
                },
                "on-remove-callback": function (event, ui) {
                    $el.show();
                    return false;
                },
                "additional-filters":
                    props.patronAutoCompleteOptions["additional-filters"],
            });
        });

        return {
            searchInputRef,
        };
    },
    name: "PatronAutoComplete",
};
</script>
