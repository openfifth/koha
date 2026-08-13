<template>
    <div class="modal show d-block" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">{{ $__("Upload plugin") }}</h5>
                    <button
                        type="button"
                        class="btn-close"
                        @click="$emit('close')"
                    ></button>
                </div>
                <div class="modal-body">
                    <div v-if="error" class="alert alert-warning">
                        {{ error }}
                    </div>
                    <p class="hint">
                        {{ $__("NOTE: Only KPZ file format is supported.") }}
                    </p>
                    <input
                        type="file"
                        accept=".kpz"
                        @change="onFileChange"
                        ref="fileInput"
                    />
                </div>
                <div class="modal-footer">
                    <button
                        class="btn btn-primary"
                        :disabled="!selectedFile"
                        @click="submit"
                    >
                        {{ $__("Upload") }}
                    </button>
                    <button class="btn btn-default" @click="$emit('close')">
                        {{ $__("Cancel") }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js";
import { inject } from "vue";

const ERROR_MESSAGES = {
    NOTKPZ: "The upload file does not appear to be a kpz file.",
    UNZIPFAIL:
        "The file failed to unpack. Please verify the integrity of the zip file and retry.",
    NOWRITEPLUGINS:
        "Cannot unpack file to the plugins directory. Please verify that the web server user can write to the plugins directory.",
    RESTRICTED:
        "Cannot install plugin from unknown source whilst plugin restriction is enabled.",
    NOWRITETEMP:
        "This server is not able to create/write to the necessary temporary directory.",
    EMPTYUPLOAD: "The upload file appears to be empty.",
    BELOWMINIMUMLEVEL:
        "This plugin does not meet the site's minimum certification level.",
};

export default {
    name: "UploadModal",
    emits: ["close", "uploaded"],
    setup() {
        const { setMessage } = inject("mainStore");
        return { setMessage };
    },
    data() {
        return {
            selectedFile: null,
            error: null,
        };
    },
    methods: {
        onFileChange(event) {
            this.selectedFile = event.target.files[0] || null;
        },
        submit() {
            this.error = null;
            const formData = new FormData();
            formData.append("file", this.selectedFile);

            const client = APIClient.plugin_store;
            client.plugins.upload(formData).then(
                () => {
                    this.setMessage(this.$__("Plugin has been installed."));
                    this.$emit("uploaded");
                    this.$emit("close");
                },
                error => {
                    this.error = this.$__(
                        ERROR_MESSAGES[error.message] ||
                            "An unknown error has occurred."
                    );
                }
            );
        },
    },
};
</script>
