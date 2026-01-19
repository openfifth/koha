<template>
    <input
        type="text"
        ref="searchInputRef"
        :placeholder="placeholder"
        :required="required && searchIsVisible"
    />
    <span id="patronautocomplete_selection"></span>
</template>

<script>
import { ref, onMounted } from "vue";
import { APIClient } from "../fetch/api-client.js";

export default {
    props: {
        id: String,
        placeholder: String,
        patronAutoCompleteOptions: Object,
        required: Boolean,
        modelValue: {
            type: [Number, Object],
            default: null,
        },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const searchInputRef = ref(null);
        const searchIsVisible = ref(true);

        onMounted(() => {
            const $searchInputRef = $(searchInputRef.value);

            const handleSelection = ui_item => {
                searchIsVisible.value = false;
                $searchInputRef.val("").focus().hide();
                emit("update:modelValue", ui_item.patron_id);
            };

            window.patron_autocomplete($searchInputRef, {
                "on-select-add-to": {
                    container: $("#patronautocomplete_selection"),
                    input_name: props.id,
                },
                "on-select-callback": (event, ui) => {
                    handleSelection(ui.item);
                    return false;
                },
                "on-remove-callback": (event, ui) => {
                    searchIsVisible.value = true;
                    $searchInputRef.show();
                    emit("update:modelValue", "");
                    return false;
                },
                "additional-filters":
                    props.patronAutoCompleteOptions?.["additional-filters"],
            });

            if (props.modelValue) {
                const client = APIClient.patron;
                client.patrons
                    .get(props.modelValue)
                    .then(p => {
                        window.patron_autocomplete_render_selection(
                            p,
                            $("#patronautocomplete_selection"),
                            props.id,
                            () => {
                                emit("update:modelValue", "");
                                $searchInputRef.show().val("").focus();
                            }
                        );
                        handleSelection(p);
                    })
                    .catch(e => {
                        console.error("Failed to fetch patron for edit:", e);
                    });
            }
        });

        return { searchInputRef, searchIsVisible };
    },
};
</script>
<style>
.patron-detail-autocomplete-selection {
    display: inline;
}
</style>
