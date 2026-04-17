/**
 * Parse a strings_map value_str into its array of repeat values.
 *
 * Backend format (see Koha::Object::Mixin::AdditionalFields::strings_map):
 *   separator ", " (comma-space); values containing , or " are wrapped in
 *   double quotes with internal quotes doubled (RFC 4180-ish). Values with
 *   no special characters pass through unquoted.
 *
 * Examples:
 *   ""                        -> []
 *   "red, blue, green"        -> ["red", "blue", "green"]
 *   '"a,b,c", b, c'           -> ["a,b,c", "b", "c"]
 *   '"she said ""hi""", ok'   -> ['she said "hi"', "ok"]
 */
const HTML_ESCAPE_MAP = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
};

export function escapeHtml(s) {
    return String(s ?? "").replace(/[&<>"']/g, c => HTML_ESCAPE_MAP[c]);
}

export function parseValueStr(valueStr) {
    if (valueStr == null || valueStr === "") return [];
    const values = [];
    const n = valueStr.length;
    let i = 0;
    while (i < n) {
        let value = "";
        if (valueStr[i] === '"') {
            i++;
            while (i < n) {
                if (valueStr[i] === '"') {
                    if (i + 1 < n && valueStr[i + 1] === '"') {
                        value += '"';
                        i += 2;
                    } else {
                        i++;
                        break;
                    }
                } else {
                    value += valueStr[i];
                    i++;
                }
            }
        } else {
            while (i < n && valueStr[i] !== ",") {
                value += valueStr[i];
                i++;
            }
        }
        values.push(value);
        if (i < n && valueStr[i] === ",") {
            i++;
            if (i < n && valueStr[i] === " ") i++;
        }
    }
    return values;
}
