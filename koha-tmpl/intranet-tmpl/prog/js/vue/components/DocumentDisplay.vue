<template>
    <label>{{ $__("Documents") }}</label>
    <div id="resource_documents">
        <ul>
            <li
                v-for="document in resource.documents"
                v-bind:key="documentUrl(document)"
            >
                <div v-if="document.file_name">
                    <span v-if="document.file_description"
                        >{{ document.file_description }} -
                    </span>
                    <a download :href="documentUrl(document)">
                        {{ document.file_name }}
                        <i class="fa fa-download"></i>
                    </a>
                    ({{ document.file_type }}) Uploaded on:
                    {{ format_date(document.uploaded_on) }}
                </div>
                <div v-if="document.physical_location">
                    {{ $__("Physical location") }}:
                    {{ document.physical_location }}
                </div>
                <div v-if="document.uri">
                    {{ $__("URI") }}: {{ document.uri }}
                </div>
                <div v-if="document.notes">
                    {{ $__("Notes") }}: {{ document.notes }}
                </div>
            </li>
        </ul>
    </div>
</template>

<script>
export default {
    props: {
        resource: Object,
        documentUrl: {
            type: Function,
            required: true,
        },
    },
    setup() {
        const format_date = $date;

        return {
            format_date,
        };
    },
};
</script>

<style></style>
