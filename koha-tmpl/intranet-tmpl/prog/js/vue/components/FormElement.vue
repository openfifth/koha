<template>
    <label
        v-if="attr.label && attr.type !== 'button'"
        :for="getElementId"
        :class="{ required }"
        :style="{ ...attr.style }"
        >{{ attr.label }}:</label
    >
    <template v-if="attr.type == 'number'">
        <InputNumber
            :id="getElementId"
            v-model="resource[attr.name]"
            :placeholder="getPlaceholder"
            :required="required"
            :size="attr.size"
            :maxlength="attr.maxlength"
            :disabled="disabled"
            @update:modelValue="checkForInputErrorAndRunOnChangeHandler()"
            :formatInputValue="attr.formatInputValue"
            :resource="resource"
        />
    </template>
    <template v-else-if="attr.type == 'text'">
        <InputText
            :id="getElementId"
            v-model="resource[attr.name]"
            :placeholder="getPlaceholder"
            :required="required"
            :disabled="disabled"
            @update:modelValue="checkForInputErrorAndRunOnChangeHandler()"
            :classNames="attr.class"
        />
    </template>
    <template v-else-if="attr.type == 'textarea'">
        <TextArea
            :id="getElementId"
            v-model="resource[attr.name]"
            :rows="attr.textAreaRows"
            :cols="attr.textAreaCols"
            :placeholder="getPlaceholder"
            :required="required"
            :disabled="disabled"
            @update:modelValue="checkForInputErrorAndRunOnChangeHandler()"
        />
    </template>
    <template v-else-if="attr.type == 'checkbox'">
        <InputCheckbox
            :id="getElementId"
            type="checkbox"
            v-model="resource[attr.name]"
            :changeMethod="attr.onChange && attr.onChange.bind(this, resource)"
            :disabled="disabled"
        />
    </template>
    <template v-else-if="attr.type == 'radio'">
        <template
            v-for="(option, index) in attr.options"
            :key="`radio-option-${index}`"
        >
            <label
                v-if="option.description"
                :for="attr.name + '_' + option.value"
                >{{ option.description }}:
                <InputRadio
                    :name="attr.name"
                    :id="attr.name + '_' + option.value"
                    :value="option.value"
                    :checked="
                        (!Object.keys(resource).includes(attr.name) &&
                            attr.default == option.value) ||
                        (Object.keys(resource).includes(attr.name) &&
                            option.value == resource[attr.name])
                    "
                    v-model="resource[attr.name]"
                    @change="
                        attr.onChange && attr.onChange.call(this, resource)
                    "
                    :disabled="option.disabled"
                />
            </label>
        </template>
    </template>
    <template v-else-if="attr.type == 'boolean'">
        <label class="radio" :for="getElementId + '_yes'"
            >{{ $__("Yes") }}:
            <InputRadio
                type="radio"
                :name="attr.name"
                :id="attr.name + '_yes'"
                :value="true"
                :checked="resource[attr.name] == true"
                v-model="resource[attr.name]"
            />
        </label>
        <label class="radio" :for="getElementId + '_no'"
            >{{ $__("No") }}:
            <InputRadio
                type="radio"
                :name="attr.name"
                :id="attr.name + '_no'"
                :checked="resource[attr.name] == false"
                :value="false"
                v-model="resource[attr.name]"
            />
        </label>
    </template>
    <template v-else-if="attr.type == 'select'">
        <v-select
            :id="getElementId"
            v-model="resource[attr.name]"
            :label="attr.treeSelect ? '_displayName' : attr.selectLabel"
            :reduce="av => selectRequiredKey(av)"
            :options="treeSelectOptions"
            :required="resource[attr.name] == null && required"
            :disabled="disabled"
            :multiple="attr.allowMultipleChoices"
            @update:modelValue="
                attr.onSelected && attr.onSelected($event, options, resource)
            "
        >
            <template v-if="required" #search="{ attributes, events }">
                <input
                    :required="resource[attr.name] == null"
                    class="vs__search"
                    v-bind="attributes"
                    v-on="events"
                />
            </template>
            <template v-if="attr.treeSelect" #option="option">
                <span :style="{ paddingLeft: option._depth * 1.5 + 'rem' }">{{
                    option._displayName
                }}</span>
            </template>
            <template v-if="attr.treeSelect" #selected-option="option">
                {{ option[attr.selectLabel] }}
            </template>
        </v-select>
    </template>
    <template v-else-if="attr.type == 'indented_subfields'">
        <fieldset>
            <ol>
                <li
                    v-for="(subfield, subFieldIndex) in attr.subFields"
                    v-bind:key="subFieldIndex"
                >
                    <FormElement
                        :resource="resource"
                        :attr="subfield"
                        :index="subFieldIndex"
                    />
                </li>
            </ol>
        </fieldset>
    </template>
    <template v-else-if="attr.type == 'vendor'">
        <component
            :is="requiredComponent"
            :id="getElementId"
            v-bind="getComponentProps()"
            v-on="getEventHandlers()"
            v-model="resource[attr.name]"
        ></component>
    </template>
    <template v-else-if="attr.type == 'date'">
        <component
            :is="requiredComponent"
            :id="getElementId"
            v-bind="getComponentProps()"
            v-on="getEventHandlers()"
            v-model="resource[attr.name]"
            :classNames="attr.class"
        ></component>
    </template>
    <template v-else-if="attr.type == 'component' && attr.componentPath">
        <component
            v-if="isVModelRequired(attr.componentPath)"
            :is="requiredComponent"
            v-bind="getComponentProps()"
            v-model="resource[attr.name]"
            v-on="getEventHandlers()"
        ></component>
        <component
            v-else
            :is="requiredComponent"
            v-bind="getComponentProps()"
            v-on="getEventHandlers()"
        ></component>
    </template>
    <template
        v-else-if="attr.type == 'relationshipWidget' && attr.componentProps"
    >
        <component
            :is="requiredComponent"
            :title="attr.group ? null : attr.label"
            :apiClient="attr.apiClient"
            :name="attr.name"
            v-bind="getComponentProps()"
            v-on="getEventHandlers()"
        ></component>
    </template>
    <template v-else-if="attr.type == 'relationshipSelect'">
        <FormRelationshipSelect
            v-bind="attr"
            :disabled="disabled"
            :resource="resource"
        ></FormRelationshipSelect>
    </template>
    <template v-else-if="attr.type == 'additional_fields'">
        <AdditionalFieldsEntry
            :resource="resource"
            :additional_field_values="resource.extended_attributes"
            :extended_attributes_resource_type="
                attr.extended_attributes_resource_type
            "
            @additional-fields-changed="additionalFieldsChanged"
        ></AdditionalFieldsEntry>
    </template>
    <template v-else-if="attr.type == 'patronSearch'">
        <PatronSearch v-bind="getComponentProps()" />
    </template>
    <template v-else-if="attr.type == 'display'">
        <span>{{
            attr?.format ? formatValue(attr, resource) : resource[attr.name]
        }}</span>
    </template>
    <template v-else-if="attr.type == 'hidden'">
        <input type="hidden" />
    </template>
    <template v-else-if="attr.type == 'button'">
        <input
            type="button"
            :class="[
                'btn',
                resource[attr.name] === attr.activeValue
                    ? 'btn-primary'
                    : 'btn-default',
            ]"
            :value="attr.label"
            @click="
                resource[attr.name] = attr.activeValue;
                attr.onClick && attr.onClick(resource);
            "
        />
    </template>
    <template v-else>
        <span>{{
            $__("Programming error: unknown type %s").format(attr.type)
        }}</span>
    </template>
    <ToolTip v-if="attr.toolTip" :toolTip="attr.toolTip"></ToolTip>
    <span v-if="required" class="required">{{ $__("Required") }}</span>
    <span style="margin-left: 5px" class="error" v-if="fieldInputError">
        {{ attr.formErrorMessage }}
    </span>
    <span v-if="getHint" class="hint" style="margin-left: 5px">{{
        getHint
    }}</span>
</template>

<script>
import AdditionalFieldsEntry from "./AdditionalFieldsEntry.vue";
import InputText from "./Elements/InputText.vue";
import InputNumber from "./Elements/InputNumber.vue";
import InputCheckbox from "./Elements/InputCheckbox.vue";
import TextArea from "./Elements/TextArea.vue";
import FormRelationshipSelect from "./FormRelationshipSelect.vue";
import ToolTip from "./ToolTip.vue";
import InputRadio from "./Elements/InputRadio.vue";
import { useBaseElement } from "../composables/base-element.js";
import { computed, defineAsyncComponent, ref } from "vue";
import { loadComponent } from "@koha-vue/loaders/componentResolver";
import PatronSearch from "./PatronSearch.vue";

export default {
    props: {
        resource: Object | null,
        attr: Object | null,
        index: Number | null,
        options: Array | null,
    },
    setup(props) {
        const baseElement = useBaseElement({ ...props });
        const selectRequiredKey = av => {
            if (props.attr.requiredKey == "package_id")
                return parseInt(av[props.attr.requiredKey]);
            return av[props.attr.requiredKey];
        };
        const isVModelRequired = componentPath => {
            let vModelRequired = true;
            const componentsNotRequiringVModel = [
                "Documents",
                "AdditionalFields",
            ];
            componentsNotRequiringVModel.forEach(component => {
                if (componentPath.includes(component)) {
                    vModelRequired = false;
                }
            });
            return vModelRequired;
        };
        const getEventHandlers = () => {
            if (props.attr.events == null) return {};
            return props.attr.events.reduce((acc, event) => {
                acc[event.name] = event.callback;
                return acc;
            }, {});
        };
        const getElementId = computed(() => {
            const { attr } = props;
            return attr.id
                ? attr.id
                : attr.relationshipName && attr.indexRequired
                  ? `${attr.relationshipName}_${attr.name}_${props.index}`
                  : attr.indexRequired
                    ? `${attr.name}_${props.index}`
                    : attr.name;
        });
        const requiredComponent = computed(() => {
            const importPath = baseElement.identifyAndImportComponent(
                props.attr
            );
            return defineAsyncComponent(loadComponent(importPath));
        });
        const selectOptions = computed(() => {
            if (props.attr.options) {
                return Array.isArray(props.attr.options)
                    ? props.attr.options
                    : props.attr.options.value;
            }
            return props.options;
        });
        const treeSelectOptions = computed(() =>
            props.attr.treeSelect
                ? props.attr.treeSelectOptionsHandler(selectOptions.value)
                : selectOptions.value
        );
        const getPlaceholder = computed(() => {
            if (props.attr.hasOwnProperty("placeholder")) {
                return props.attr.placeholder;
            }
            return props.attr.placeholder || props.attr.label;
        });
        const disabled = computed(() => {
            const disabledAttr = props.disabled || props.attr.disabled;
            if (typeof disabledAttr === "function") {
                return disabledAttr(props.resource);
            } else {
                return disabledAttr || false;
            }
        });
        const required = computed(() => {
            const requiredAttr = props.required || props.attr.required;
            if (typeof requiredAttr === "function") {
                return requiredAttr(props.resource);
            } else {
                return requiredAttr || false;
            }
        });

        const fieldInputError = ref(false);
        const checkForInputErrorAndRunOnChangeHandler = () => {
            if (props.attr.formErrorHandler) {
                fieldInputError.value = !props.attr.formErrorHandler(
                    props.resource[props.attr.name]
                );
            }
            if (!fieldInputError.value && props.attr.onChange) {
                props.attr.onChange(props.resource);
            }
        };

        const getHint = computed(() => {
            if (props.attr.hint && typeof props.attr.hint === "function") {
                return props.attr.hint(props.resource);
            } else {
                return props.attr.hint || "";
            }
        });

        return {
            ...baseElement,
            selectRequiredKey,
            isVModelRequired,
            getEventHandlers,
            getElementId,
            requiredComponent,
            selectOptions,
            treeSelectOptions,
            disabled,
            fieldInputError,
            checkForInputErrorAndRunOnChangeHandler,
            getPlaceholder,
            getHint,
            required,
        };
    },
    name: "FormElement",
    components: {
        FormRelationshipSelect,
        ToolTip,
        AdditionalFieldsEntry,
        InputText,
        InputNumber,
        InputCheckbox,
        TextArea,
        InputRadio,
        PatronSearch,
    },
};
</script>

<style scoped>
/* Chrome, Safari, Edge, Opera */
input::-webkit-outer-spin-button,
input::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
}

/* Firefox */
input[type="number"] {
    -moz-appearance: textfield;
}

.filters > input[type="radio"] {
    min-width: 0 !important;
}
</style>
