<template>
    <div v-if="visible">
        <div
            class="modal d-block"
            tabindex="-1"
            role="dialog"
            aria-labelledby="bound-with-modal-label"
        >
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h1
                            v-if="unlinking"
                            class="modal-title"
                            id="bound-with-modal-label"
                        >
                            {{ $__("Remove bound-with link") }}
                        </h1>
                        <h1
                            v-else
                            class="modal-title"
                            id="bound-with-modal-label"
                        >
                            {{ $__("Bound-with links") }}
                        </h1>
                        <button
                            type="button"
                            class="btn-close"
                            :aria-label="$__('Close')"
                            @click="close"
                        ></button>
                    </div>
                    <div class="modal-body">
                        <div v-if="error" class="alert alert-warning">
                            {{ error }}
                        </div>

                        <template v-if="unlinking">
                            <p>
                                {{
                                    $__(
                                        "Are you sure you want to remove the bound-with link between item"
                                    )
                                }}
                                <strong>{{ item.external_id }}</strong>
                                {{ $__("and") }}
                                <strong>{{ biblioTitle(unlinking) }}</strong
                                >?
                            </p>
                            <div
                                v-if="holdsWarning"
                                class="alert alert-warning"
                            >
                                {{
                                    $__(
                                        "Holds exist for this item on the linked record. Removing the link will strand them. Cancel the holds first, or remove the link anyway."
                                    )
                                }}
                            </div>
                        </template>

                        <template v-else-if="mode == 'barcode'">
                            <p>
                                {{
                                    $__(
                                        "Enter the barcode of the item to bind to this record. The item record stays where it is, only a link is added."
                                    )
                                }}
                            </p>
                            <div class="form-group">
                                <label for="bound-with-barcode"
                                    >{{ $__("Item barcode") }}:
                                </label>
                                <input
                                    id="bound-with-barcode"
                                    v-model.trim="barcode"
                                    type="text"
                                    size="30"
                                    @keyup.enter="linkByBarcode"
                                />
                            </div>
                        </template>

                        <template v-else-if="item">
                            <p>
                                {{ $__("Item") }}
                                <strong>{{ item.external_id }}</strong> &mdash;
                                {{ $__("the item record lives on") }}
                                <a :href="detailLink(item.biblio_id)">{{
                                    item.biblio && item.biblio.title
                                        ? item.biblio.title
                                        : item.biblio_id
                                }}</a>
                            </p>
                            <h2>{{ $__("Bound with") }}</h2>
                            <table
                                v-if="bindingLinks.length"
                                id="bound-with-links-table"
                                class="table"
                            >
                                <thead>
                                    <tr>
                                        <th>{{ $__("Record") }}</th>
                                        <th>&nbsp;</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr
                                        v-for="link in bindingLinks"
                                        :key="link.item_biblio_link_id"
                                    >
                                        <td>
                                            <a
                                                :href="
                                                    detailLink(link.biblio_id)
                                                "
                                                >{{ biblioTitle(link) }}</a
                                            >
                                        </td>
                                        <td>
                                            <button
                                                class="btn btn-default btn-xs"
                                                @click="confirmUnlink(link)"
                                            >
                                                <i class="fa fa-unlink"></i>
                                                {{ $__("Remove link") }}
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <p v-else>
                                {{
                                    $__(
                                        "This item is not yet bound with any other record."
                                    )
                                }}
                            </p>
                            <h2>{{ $__("Add links") }}</h2>
                            <div class="form-group">
                                <label for="bound-with-biblionumbers"
                                    >{{ $__("Record number(s)") }}:
                                </label>
                                <input
                                    id="bound-with-biblionumbers"
                                    v-model.trim="biblionumbers"
                                    type="text"
                                    size="30"
                                    @keyup.enter="addLinks"
                                />
                                <div class="hint">
                                    {{
                                        $__(
                                            "Enter one or more biblionumbers, separated by spaces or commas"
                                        )
                                    }}
                                </div>
                            </div>
                        </template>
                    </div>
                    <div class="modal-footer">
                        <template v-if="unlinking">
                            <button
                                v-if="holdsWarning"
                                class="btn btn-danger"
                                :disabled="saving"
                                @click="unlink(true)"
                            >
                                <i class="fa fa-unlink"></i>
                                {{ $__("Remove anyway") }}
                            </button>
                            <button
                                v-else
                                class="btn btn-danger"
                                :disabled="saving"
                                @click="unlink(false)"
                            >
                                <i class="fa fa-unlink"></i>
                                {{ $__("Remove link") }}
                            </button>
                            <button
                                class="btn btn-default"
                                @click="cancelUnlink"
                            >
                                {{ $__("Cancel") }}
                            </button>
                        </template>
                        <template v-else-if="mode == 'barcode'">
                            <button
                                class="btn btn-primary"
                                :disabled="saving || !barcode.length"
                                @click="linkByBarcode"
                            >
                                <i class="fa fa-link"></i>
                                {{ $__("Link item") }}
                            </button>
                            <button class="btn btn-default" @click="close">
                                {{ $__("Close") }}
                            </button>
                        </template>
                        <template v-else>
                            <button
                                class="btn btn-primary"
                                :disabled="saving || !biblionumbers.length"
                                @click="addLinks"
                            >
                                <i class="fa fa-link"></i>
                                {{ $__("Link") }}
                            </button>
                            <button class="btn btn-default" @click="close">
                                {{ $__("Close") }}
                            </button>
                        </template>
                    </div>
                </div>
            </div>
        </div>
        <div class="modal-backdrop fade show"></div>
    </div>
</template>

<script>
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        biblionumber: String,
    },
    setup(props) {
        const visible = ref(false);
        const mode = ref("item");
        const item = ref(null);
        const barcode = ref("");
        const biblionumbers = ref("");
        const unlinking = ref(null);
        const holdsWarning = ref(false);
        const saving = ref(false);
        const error = ref(null);

        const bindingLinks = computed(() =>
            ((item.value && item.value.biblio_links) || []).filter(
                link => link.link_type == "binding"
            )
        );

        const detailLink = biblioId =>
            `/cgi-bin/koha/catalogue/detail.pl?biblionumber=${biblioId}`;

        const biblioTitle = link =>
            link.biblio && link.biblio.title
                ? link.biblio.title
                : link.biblio_id;

        const reset = () => {
            item.value = null;
            barcode.value = "";
            biblionumbers.value = "";
            unlinking.value = null;
            holdsWarning.value = false;
            saving.value = false;
            error.value = null;
        };

        const onOpen = event => {
            reset();
            if (event.detail && event.detail.item) {
                item.value = event.detail.item;
                mode.value = "item";
            } else {
                mode.value = "barcode";
            }
            visible.value = true;
        };

        const close = () => {
            visible.value = false;
        };

        const postLink = (biblioId, itemId) =>
            fetch(`/api/v1/biblios/${biblioId}/item_biblio_links`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ item_id: itemId, link_type: "binding" }),
            });

        const linkByBarcode = async () => {
            if (!barcode.value.length || saving.value) return;
            saving.value = true;
            error.value = null;
            const response = await fetch(
                `/api/v1/items?external_id=${encodeURIComponent(barcode.value)}`
            );
            const found = response.ok ? await response.json() : [];
            if (!found.length) {
                error.value = $__("No item found with this barcode");
                saving.value = false;
                return;
            }
            const result = await postLink(props.biblionumber, found[0].item_id);
            if (result.ok) {
                window.location.reload();
            } else {
                const body = await result.json().catch(() => ({}));
                error.value = body.error || result.status;
                saving.value = false;
            }
        };

        const addLinks = async () => {
            const targets = biblionumbers.value
                .split(/[\s,;]+/)
                .filter(Boolean);
            if (!targets.length || saving.value) return;
            saving.value = true;
            error.value = null;
            const failures = [];
            for (const target of targets) {
                if (!/^\d+$/.test(target)) {
                    failures.push(
                        `${target}: ${$__("not a valid record number")}`
                    );
                    continue;
                }
                const result = await postLink(target, item.value.item_id);
                if (!result.ok) {
                    const body = await result.json().catch(() => ({}));
                    failures.push(`${target}: ${body.error || result.status}`);
                }
            }
            if (failures.length) {
                error.value = failures.join("; ");
                saving.value = false;
            } else {
                window.location.reload();
            }
        };

        const confirmUnlink = link => {
            error.value = null;
            holdsWarning.value = false;
            unlinking.value = link;
        };

        const cancelUnlink = () => {
            unlinking.value = null;
            holdsWarning.value = false;
            error.value = null;
        };

        const unlink = async force => {
            if (saving.value) return;
            saving.value = true;
            error.value = null;
            const url =
                `/api/v1/biblios/${unlinking.value.biblio_id}/item_biblio_links/${unlinking.value.item_biblio_link_id}` +
                (force ? "?force=1" : "");
            const result = await fetch(url, { method: "DELETE" });
            if (result.status == 204) {
                window.location.reload();
            } else {
                const body = await result.json().catch(() => ({}));
                if (result.status == 409 && body.error_code == "holds_exist") {
                    holdsWarning.value = true;
                } else {
                    error.value = body.error || result.status;
                }
                saving.value = false;
            }
        };

        onMounted(() => {
            window.addEventListener("bound-with:open", onOpen);
            if (window.location.hash == "#boundwith") {
                onOpen({ detail: {} });
            }
        });
        onBeforeUnmount(() => {
            window.removeEventListener("bound-with:open", onOpen);
        });

        return {
            visible,
            mode,
            item,
            barcode,
            biblionumbers,
            unlinking,
            holdsWarning,
            saving,
            error,
            bindingLinks,
            detailLink,
            biblioTitle,
            onOpen,
            close,
            linkByBarcode,
            addLinks,
            confirmUnlink,
            cancelUnlink,
            unlink,
        };
    },
};
</script>
