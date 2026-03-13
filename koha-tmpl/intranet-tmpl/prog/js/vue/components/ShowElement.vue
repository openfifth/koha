<template>
    <template
        v-if="
            (attribute.type == 'text' ||
                attribute.type == 'textarea' ||
                (attribute.type == 'select' && !attribute.avCat) ||
                attribute?.type == 'date' ||
                attribute.type == 'number') &&
            (!attribute.hidden ||
                (attribute.hidden && attribute.hidden(resource)))
        "
    >
        <label>{{ attribute.label }}:</label>
        <LinkWrapper :linkData="attribute?.link" :resource="resource">
            <span>
                {{
                    attribute?.format ||
                    (attribute.value && attribute?.value.includes("."))
                        ? formatValue(attribute, resource)
                        : resource[attribute.name]
                }}
            </span>
        </LinkWrapper>
    </template>
    <template v-else-if="attribute.type == 'radio'">
        <label>{{ attribute.label }}:</label>
        <span>{{ radioOptionText }}</span>
    </template>
    <template
        v-else-if="
            attribute.type == 'av' ||
            (attribute.type == 'select' && attribute.avCat)
        "
    >
        <label>{{ attribute.label }}:</label>
        <LinkWrapper :linkData="attribute?.link" :resource="resource">
            <span>{{
                instancedResource.get_lib_from_av(
                    attribute.avCat,
                    resource[attribute.name]
                )
            }}</span>
        </LinkWrapper>
    </template>
    <template
        v-else-if="attribute.type == 'boolean' || attribute.type == 'checkbox'"
    >
        <label>{{ attribute.label }}:</label>
        <span v-if="resource[attribute.name]">{{ $__("Yes") }}</span>
        <span v-else>{{ $__("No") }}</span>
    </template>
    <template v-else-if="attribute.type === 'table'">
        <template v-if="attribute.hidden && attribute.hidden(resource)">
            <label>{{ attribute.label }}</label>
            <table>
                <thead>
                    <th
                        v-for="column in tableColumns"
                        :key="column.name + 'head'"
                    >
                        {{ column.name }}
                    </th>
                </thead>
                <tbody>
                    <tr
                        v-for="(row, counter) in resource[attribute.columnData]"
                        v-bind:key="counter"
                    >
                        <td
                            v-for="dataColumn in tableColumns"
                            :key="dataColumn.name + 'data'"
                        >
                            <template
                                v-if="
                                    dataColumn.format ||
                                    dataColumn.value.includes('.')
                                "
                            >
                                <a
                                    v-if="dataColumn.computeHref"
                                    :href="dataColumn.computeHref(row)"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    >{{ formatValue(dataColumn, row) }}</a
                                >
                                <LinkWrapper
                                    v-else
                                    :linkData="dataColumn.link"
                                    :resource="row"
                                >
                                    {{ formatValue(dataColumn, row) }}
                                </LinkWrapper>
                            </template>
                            <template v-else-if="dataColumn.av">
                                <LinkWrapper
                                    :linkData="dataColumn.link"
                                    :resource="row"
                                >
                                    {{
                                        instancedResource.get_lib_from_av(
                                            dataColumn.av,
                                            row[dataColumn.value]
                                        )
                                    }}
                                </LinkWrapper>
                            </template>
                            <template v-else>
                                <a
                                    v-if="dataColumn.computeHref"
                                    :href="dataColumn.computeHref(row)"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    >{{ row[dataColumn.value] }}</a
                                >
                                <LinkWrapper
                                    v-else
                                    :linkData="dataColumn.link"
                                    :resource="row"
                                >
                                    {{ row[dataColumn.value] }}
                                </LinkWrapper>
                            </template>
                        </td>
                    </tr>
                </tbody>
            </table>
        </template>
    </template>
    <template v-else-if="attribute?.type === 'component'">
        <template
            v-if="
                !attribute.hidden ||
                (attribute.hidden && attribute.hidden(resource))
            "
        >
            <label v-if="attribute.label">{{ attribute.label }}:</label>
            <component
                :is="requiredComponent"
                v-bind="getComponentProps(true)"
            ></component>
        </template>
    </template>
    <template v-else-if="attribute.type == 'patronAutoComplete'">
        <label>{{ attribute.label }}:</label>
        <span v-if="resource[attribute.patronEmbedName]">
            <a
                :href="`/cgi-bin/koha/members/moremember.pl?borrowernumber=${resource[attribute.patronEmbedName].patron_id}`"
                >{{ formatPatronHTML(resource[attribute.patronEmbedName]) }}</a
            >
        </span>
    </template>
    <template
        v-else-if="attribute.type == 'relationship' && attribute.componentPath"
    >
        <template v-if="attribute.hidden && attribute.hidden(resource)">
            <component
                :is="requiredComponent"
                v-bind="getComponentProps(true)"
            ></component>
        </template>
    </template>
    <template v-else-if="attribute.type == 'relationshipSelect'">
        <label>{{ attribute.label }}:</label>
        <LinkWrapper
            :linkData="attribute.showElement?.link"
            :resource="resource"
        >
            <span>
                {{
                    attribute?.format ||
                    (attribute.value && attribute?.value.includes("."))
                        ? formatValue(attribute, resource)
                        : resource[attribute.name]
                }}
            </span>
        </LinkWrapper>
    </template>
    <template v-else-if="attr.type == 'static_text'">
        <label>{{ attr.label }}:</label>
        <span class="static-text-value">
            <!-- Multiple values: one link per item (e.g. per-hostname URLs) -->
            <template v-if="attr.computeValues">
                <span
                    v-for="(item, i) in attr.computeValues(resource)"
                    :key="i"
                    class="d-block"
                >
                    <a
                        :href="item.href"
                        target="_blank"
                        rel="noopener noreferrer"
                        >{{ item.label }}</a
                    >
                </span>
            </template>
            <!-- Single value -->
            <template v-else>
                <a
                    v-if="attr.href || attr.computeHref"
                    :href="
                        attr.computeHref
                            ? attr.computeHref(resource)
                            : attr.href
                    "
                    target="_blank"
                    rel="noopener noreferrer"
                >
                    {{
                        attr.computeValue
                            ? attr.computeValue(resource)
                            : attr.value
                    }}
                </a>
                <span v-else>{{
                    attr.computeValue ? attr.computeValue(resource) : attr.value
                }}</span>
            </template>
        </span>
    </template>
    <template v-else-if="attr.type == 'pem_certificate'">
        <label>{{ attr.label }}:</label>
        <pre v-if="resource[attr.name]" class="pem-block">{{
            resource[attr.name]
        }}</pre>
        <span v-else>—</span>
    </template>
    <template
        v-else-if="attr.type === 'relationshipWidget' && attr.componentProps"
    >
        <component
            :is="requiredComponent"
            :title="attr.group ? null : attr.label"
            :name="attr.name"
            v-bind="getComponentProps(true)"
        ></component>
    </template>
    <template
        v-else-if="
            attr.type == 'additional_fields' &&
            resource._strings?.additional_field_values.length > 0
        "
    >
        <AdditionalFieldsDisplay
            :additional_field_values="resource._strings.additional_field_values"
            :extended_attributes_resource_type="
                attr.extended_attributes_resource_type
            "
        ></AdditionalFieldsDisplay>
    </template>
</template>

<script>
import LinkWrapper from "./LinkWrapper.vue";
import AdditionalFieldsDisplay from "./AdditionalFieldsDisplay.vue";
import { useBaseElement } from "../composables/base-element.js";
import { computed, defineAsyncComponent, unref } from "vue";

import { loadComponent } from "@koha-vue/loaders/componentResolver";

export default {
    components: { LinkWrapper, AdditionalFieldsDisplay },
    setup(props) {
        const baseElement = useBaseElement({ ...props });

        const requiredComponent = computed(() => {
            const importPath = baseElement.identifyAndImportComponent(
                props.attr,
                true
            );
            return defineAsyncComponent(loadComponent(importPath));
        });
        const attribute = computed(() => {
            if (props.attr.showElement) {
                return { ...props.attr, ...props.attr.showElement };
            }
            return props.attr;
        });

        const formatPatronHTML = patron => {
            if (typeof $patron_to_html === "function") {
                return $patron_to_html(patron);
            }
            return "";
        };

        const formatValue = (attr, resource) => {
            const valueKey = attr.hasOwnProperty("value")
                ? attr.value
                : attr.name;
            if (valueKey?.includes(".")) {
                return baseElement.accessNestedProperty(valueKey, resource);
            }
            const displayValue = attr.format(resource[valueKey], resource);
            if (displayValue == "Invalid date") {
                return "";
            }
            return displayValue || "";
        };
        const radioOptionText = computed(() => {
            if (!attribute.value.value || !attribute.value.options.length)
                return "";
            const option = attribute.value.options.find(
                option => option.value == props.resource[attribute.value.name]
            );
            return option.description;
        });
        const tableColumns = computed(() => {
            const tableData = props.resource[attribute.value.columnData];
            // columns may be a plain array or a Vue ref (for dynamic column sets)
            const columns = unref(attribute.value.columns);
            if (attribute.value.includeAdditionalFields && tableData?.length) {
                const additionalFieldColumns = tableData.reduce((acc, curr) => {
                    if (curr._strings?.additional_field_values.length) {
                        curr._strings.additional_field_values.forEach(av => {
                            if (!acc.includes(av.field_label)) {
                                acc.push(av.field_label);
                            }
                            curr[av.field_label] = av.value_str;
                        });
                    }
                    return acc;
                }, []);
                additionalFieldColumns.forEach(col => {
                    columns.push({
                        name: col,
                        value: col,
                    });
                });
            }
            return columns;
        });

        return {
            ...baseElement,
            requiredComponent,
            attribute,
            formatValue,
            radioOptionText,
            tableColumns,
            formatPatronHTML,
        };
    },
    props: {
        resource: Object | null,
        attr: Object | null,
        instancedResource: Object | null,
    },
    name: "ShowElement",
};
</script>

<style scoped>
.pem-block {
    font-family: monospace;
    font-size: 0.8em;
    background: #f8f8f8;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 0.5em 0.75em;
    max-height: 10em;
    overflow-y: auto;
    white-space: pre;
    word-break: break-all;
}
</style>
