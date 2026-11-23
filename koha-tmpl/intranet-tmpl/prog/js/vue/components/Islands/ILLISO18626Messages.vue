<template>
    <div v-if="messages.length" class="page-section">
        <h3>{{ $__("ISO18626 messages") }}</h3>
        <ISO18626MessageDisplay :messages="messages" requesting />
    </div>
    <Dialog />
</template>

<script>
import { onMounted, ref } from "vue";
import { APIClient } from "../../fetch/api-client.js";
import Dialog from "../Dialog.vue";
import ISO18626MessageDisplay from "../ILL/ISO18626MessageDisplay.vue";

export default {
    props: {
        illrequestId: {
            type: String,
            required: true,
        },
    },
    setup(props) {
        const messages = ref([]);

        onMounted(() => {
            APIClient.ill.requests
                .getAll(
                    { "me.ill_request_id": props.illrequestId },
                    {},
                    { "x-koha-embed": "iso18626_messages" }
                )
                .then(requests => {
                    messages.value = requests?.[0]?.iso18626_messages ?? [];
                });
        });

        return { messages };
    },
    components: {
        Dialog,
        ISO18626MessageDisplay,
    },
};
</script>
