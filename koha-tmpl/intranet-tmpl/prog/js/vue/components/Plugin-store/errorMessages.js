// Deliberately does NOT include UNSIGNEDCONFIRMREQUIRED -- that code is not a terminal
// error to display, it's a signal to show a confirmation dialog and retry. Handling it
// as a generic message here would be wrong; each call site special-cases it before
// falling through to this map.
export const ERROR_MESSAGES = {
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
    SIGNATUREMISMATCH:
        "This file's signature doesn't match what the store signed -- it may have been altered or corrupted.",
    UNSIGNED:
        "This plugin is not signed by the plugin store, and this site requires a valid signature to install.",
};

export default ERROR_MESSAGES;
