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
                            v-else-if="managing"
                            class="modal-title"
                            id="bound-with-modal-label"
                        >
                            {{ $__("Bound-with links") }}
                        </h1>
                        <h1
                            v-else
                            class="modal-title"
                            id="bound-with-modal-label"
                        >
                            {{ $__("Bound-with records") }}
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
                                        <th v-if="managing">&nbsp;</th>
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
                                        <td v-if="managing">
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
                            <template v-if="managing">
                                <h2>{{ $__("Add links") }}</h2>
                                <div class="form-group">
                                    <label for="bound-with-targets"
                                        >{{ $__("Records to link") }}:
                                    </label>
                                    <FormRelationshipSelect
                                        name="targets"
                                        :resource="linkTarget"
                                        :allowMultipleChoices="true"
                                        :serverSearch="true"
                                        :relationshipAPIClient="biblioClient"
                                        relationshipOptionLabelAttr="title"
                                        :searchQueryBuilder="buildBiblioQuery"
                                        :searchPlaceholder="
                                            $__(
                                                'Title, author, ISBN or record number'
                                            )
                                        "
                                    >
                                        <template #option="biblio">
                                            <strong>{{ biblio.title }}</strong>
                                            <template v-if="biblio.author">
                                                / {{ biblio.author }}</template
                                            >
                                            ({{ $__("Record number") }}
                                            {{ biblio.biblio_id }})
                                        </template>
                                    </FormRelationshipSelect>
                                    <div class="hint">
                                        {{
                                            $__(
                                                "Search by title, author or ISBN, or enter a record number directly"
                                            )
                                        }}
                                    </div>
                                </div>
                            </template>
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
                                v-if="managing"
                                class="btn btn-primary"
                                :disabled="saving || !linkTarget.targets.length"
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
import { APIClient } from "../../fetch/api-client.js";
import FormRelationshipSelect from "../FormRelationshipSelect.vue";
import "vue-select/dist/vue-select.css";

export default {
    components: { FormRelationshipSelect },
    props: {
        biblionumber: String,
        canManage: String,
    },
    setup(props) {
        const biblioClient = APIClient.biblio.biblios;

        const manageAllowed = computed(() => props.canManage == "1");

        const visible = ref(false);
        const mode = ref("item");
        const managing = ref(false);
        const item = ref(null);
        const barcode = ref("");
        const linkTarget = ref({ targets: [] });
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

        const excludedBiblioIds = computed(() => [
            ...(item.value ? [item.value.biblio_id] : []),
            ...bindingLinks.value.map(link => link.biblio_id),
            ...linkTarget.value.targets.map(target => target.biblio_id),
        ]);

        const buildBiblioQuery = term => {
            const clauses = [
                { "me.title": { "-like": `%${term}%` } },
                { "me.author": { "-like": `%${term}%` } },
            ];
            if (/^\d+$/.test(term))
                clauses.push({ "me.biblio_id": Number(term) });
            const isbn = term.replace(/[\s-]/g, "");
            if (/^\d{9}[\dXx]$/.test(isbn) || /^\d{13}$/.test(isbn))
                clauses.push({ isbn: { "-like": `%${isbn}%` } });
            return {
                "-and": [
                    { "-or": clauses },
                    { "me.biblio_id": { "-not_in": excludedBiblioIds.value } },
                ],
            };
        };

        const reset = () => {
            managing.value = false;
            item.value = null;
            barcode.value = "";
            linkTarget.value = { targets: [] };
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
                managing.value = !!(event.detail.manage && manageAllowed.value);
            } else {
                // Barcode mode adds a link, so it needs the manage permission
                if (!manageAllowed.value) return;
                mode.value = "barcode";
                managing.value = true;
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
            const targets = linkTarget.value.targets;
            if (!targets.length || saving.value) return;
            saving.value = true;
            error.value = null;
            const failures = [];
            const remaining = [];
            for (const target of targets) {
                const result = await postLink(
                    target.biblio_id,
                    item.value.item_id
                );
                if (!result.ok) {
                    const body = await result.json().catch(() => ({}));
                    failures.push(
                        `${target.title}: ${body.error || result.status}`
                    );
                    remaining.push(target);
                }
            }
            if (failures.length) {
                linkTarget.value = { targets: remaining };
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
            managing,
            item,
            barcode,
            biblioClient,
            linkTarget,
            buildBiblioQuery,
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
