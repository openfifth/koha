[% USE Koha %]
[% USE Branches %]
[% USE Asset %]
[% USE raw %]
[% USE To %]

<circ-nav
    superlibrarian="[% CAN_user_superlibrarian | html %]"
    loggedinlibrary="[% CAN_user_loggedinlibrary | html %]"
    usecirculationdesks="[% Koha.Preference('UseCirculationDesks') | html %]"
    fastcatalogingpref="[% fast_cataloging | html %]"
    fastcataloging="[% CAN_user_editcatalogue_fast_cataloging | html %]"
    allowcheckoutnotes="[% Koha.Preference('AllowCheckoutNotes') | html %]"
    managecheckoutnotes="[% CAN_user_circulate_manage_checkout_notes | html %]"
    onsitecheckouts="[% Koha.Preference('OnSiteCheckouts') | html %]"
    useholdsqueuefilteroptions="[% Koha.Preference('UseHoldsQueueFilterOptions') | html %]"
    loggedinbranchcode="[% Branches.GetLoggedInBranchcode | html %]"
    curbsidepickup="[% Koha.Preference('CurbsidePickup') | html %]"
    managecurbsidepickups="[% CAN_user_circulate_manage_curbside_pickups | html %]"
    userecalls="[% Koha.Preference('UseRecalls') | html %]"
    recalls="[% CAN_user_recalls | html %]"
    articlerequests="[% Koha.Preference('ArticleRequests') | html %]"
    independentbranchestransfers="[% Koha.Preference('IndependentBranchesTransfers') | html %]"
    stockrotation="[% Koha.Preference('StockRotation') | html %]"
    overduesreport="[% CAN_user_circulate_overdues_report | html %]"
></circ-nav>
