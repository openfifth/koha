import { $__ } from "@koha-vue/i18n";

export const recordTypes = [
    { value: "biblio", label: $__("Bibliographic") },
    { value: "auth", label: $__("Authority") },
];

export const encodings = [
    { value: "UTF-8", label: $__("UTF-8 (Default)") },
    { value: "MARC-8", label: $__("MARC 8") },
    { value: "ISO_5426", label: $__("ISO 5426") },
    { value: "ISO_6937", label: $__("ISO 6937") },
    { value: "ISO_8859-1", label: $__("ISO 8859-1") },
    { value: "EUC-KR", label: $__("EUC-KR") },
];

export const formats = [
    { value: "ISO2709", label: $__("MARC") },
    { value: "MARCXML", label: $__("MARCXML") },
];

export const overlayActions = [
    {
        value: "replace",
        label: $__("Replace existing record with incoming record"),
    },
    { value: "create_new", label: $__("Add incoming record") },
    {
        value: "ignore",
        label: $__("Ignore incoming record (its items may still be processed)"),
    },
];

export const nomatchActions = [
    { value: "create_new", label: $__("Add incoming record") },
    { value: "ignore", label: $__("Ignore incoming record") },
];

export const itemActions = [
    { value: "always_add", label: $__("Always add items") },
    {
        value: "add_only_for_matches",
        label: $__("Add items only if matching bib was found"),
    },
    {
        value: "add_only_for_new",
        label: $__("Add items only if no matching bib was found"),
    },
    {
        value: "replace",
        label: $__(
            "Replace items if matching bib was found (only for existing items)"
        ),
    },
    { value: "ignore", label: $__("Ignore items") },
];
