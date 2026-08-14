<template>
    <div>
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
        <div class="mt-3">
            <button
                class="btn btn-primary"
                :disabled="!selectedFile"
                @click="submit(false)"
            >
                {{ $__("Upload") }}
            </button>
        </div>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js";
import { ERROR_MESSAGES } from "./errorMessages.js";
import { inject } from "vue";

export default {
    name: "UploadModal",
    emits: ["uploaded"],
    setup() {
        const { setMessage, setConfirmationDialog } = inject("mainStore");
        return { setMessage, setConfirmationDialog };
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
        submit(confirmUnsigned = false) {
            this.error = null;
            const formData = new FormData();
            formData.append("file", this.selectedFile);
            if (confirmUnsigned) formData.append("confirm_unsigned", "1");

            const client = APIClient.plugin_store;
            client.plugins.upload(formData).then(
                () => {
                    this.setMessage(this.$__("Plugin has been installed."));
                    this.$emit("uploaded");
                },
                error => {
                    if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
                        this.setConfirmationDialog(
                            {
                                title: this.$__(
                                    "This plugin isn't signed by the plugin store. It may be a private/in-house plugin the store has never seen, or one published before this store supported signing. Install anyway?"
                                ),
                                accept_label: this.$__("Yes, install anyway"),
                                cancel_label: this.$__("No, cancel"),
                            },
                            () => this.submit(true)
                        );
                        return;
                    }
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
