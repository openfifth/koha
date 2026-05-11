[% USE raw %]
[% USE Asset %]
[% USE Koha %]
[% USE KohaPlugins %]
[% USE String %]
[% PROCESS 'html_helpers.inc' %]
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="csrf-token" content="[% Koha.GenerateCSRF | $raw %]" />
[% IF logged_in_user %]<meta name="generator" content="Koha [% Koha.Version.maintenance | html %]" />[% END %]
<script nonce="[% Koha.CSPNonce | $raw %]">
    window.__CSP_NONCE__ = "[% Koha.CSPNonce | $raw %]";
</script>
[%# Import map for bare-specifier resolution in ESM bundles.
    Maps "vue" to the shared Vue runtime so every ESM bundle reuses the
    same Vue instance, and "jQuery" / "DataTable" to small shims that
    re-export the corresponding window globals.

    Per the HTML spec, an import map MUST appear before any
    <script type="module">
 that uses bare specifiers — once a module
    starts loading, adding or replacing the map is a no-op for it. Do
    not move this block below any module-script tag, and do not inline
    a module-script in <head> before this point.
-%]
[%- SET vue_esm_src = Asset.js("js/vue/dist/vue.esm.js").match('src="([^"]+)"').0 -%]
[%- SET jquery_shim_src = Asset.js("js/shims/jquery.esm.js").match('src="([^"]+)"').0 -%]
[%- SET dt_shim_src = Asset.js("js/shims/datatables.esm.js").match('src="([^"]+)"').0 -%]
<script type="importmap" nonce="[% Koha.CSPNonce | $raw %]">
    {
        "imports": {
            "vue": "[% vue_esm_src | $raw %]",
            "jQuery": "[% jquery_shim_src | $raw %]",
            "DataTable": "[% dt_shim_src | $raw %]"
        }
    }
</script>
[%# Prevent XFS attacks -%]
[% UNLESS popup %]
    <style nonce="[% Koha.CSPNonce | $raw %]" id="antiClickjack">
        body {
            display: none !important;
        }
    </style>
[% END %]

<link rel="shortcut icon" href="[% IF ( IntranetFavicon ) %][% IntranetFavicon | html %][% ELSE %][% interface | html %]/[% theme | html %]/img/favicon.ico[% END %]" type="image/x-icon" />

[% IF ( bidi ) %]
    [% Asset.css("lib/jquery/jquery-ui-rtl-1.13.2.min.css") | $raw %]
[% ELSE %]
    [% Asset.css("lib/jquery/jquery-ui-1.13.2.min.css") | $raw %]
[% END %]
[% Asset.css("lib/datatables/datatables.min.css") | $raw %]
[% Asset.css("css/print.css", { media = "print" }) | $raw %]
[% INCLUDE intranetstylesheet.inc %]
<script nonce="[% Koha.CSPNonce | $raw %]" type="module">
    import { APIClient } from "/intranet-tmpl/prog/js/fetch/api-client.js";
    window.APIClient = APIClient;
</script>
<script nonce="[% Koha.CSPNonce | $raw %]">
    var Koha = {};
    [% IF CAN_user_parameters_manage_column_config %]
        var CAN_user_parameters_manage_column_config = 1;
    [% ELSE %]
        var CAN_user_parameters_manage_column_config = 0;
    [% END %]
</script>
[% IF lang && lang != 'en' %]
    [% Asset.js(lang _ '/js/locale_data.js') | $raw %]
[% END %]
[% Asset.js('js/Gettext.js') | $raw %]
[% Asset.js('js/i18n.js') | $raw %]
[% Asset.js('js/stores.js') | $raw %]

[% IF ( login ) %]
    [% Asset.css("css/login.css") | $raw %]
[% END %]

[% IF ( IntranetUserCSS ) %]
    <!-- prettier-ignore-start -->
    <style nonce="[% Koha.CSPNonce | $raw %]">[% IntranetUserCSS | $raw %]</style>
    <!-- prettier-ignore-end -->
[% END %]

[% KohaPlugins.get_plugins_intranet_head | $raw %]

[% UNLESS ( footerjs ) %]
    [% INCLUDE js_includes.inc %]
[% END %]
