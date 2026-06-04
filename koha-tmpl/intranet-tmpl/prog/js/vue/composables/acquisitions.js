import { BigNumber } from "bignumber.js";
import { APIClient } from "../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

BigNumber.config({ DECIMAL_PLACES: 6 });

/**
 * Rounds a numeric value to 2 decimal places using ROUND_HALF_UP.
 * Converts the input via BigNumber to avoid floating-point precision issues.
 *
 * @param {number|string|null|undefined} value - The value to format.
 * @returns {number} The value rounded to 2 decimal places, or 0 if value is nullish.
 */
const formatFloatingPoint = value => {
    return new BigNumber(String(value ?? 0))
        .decimalPlaces(2, BigNumber.ROUND_HALF_UP)
        .toNumber();
};

/**
 * Formats a numeric value as a price string, optionally suffixed with a currency code.
 * Uses `format_price()` (Koha browser global) for locale-aware formatting.
 * Negative values are rendered as "-{amount} {currency}".
 *
 * @param {number|string|null} value    - The amount to format.
 * @param {string|null}        currency - ISO currency code to append (e.g. "GBP"),
 *   or null/undefined to omit.
 * @returns {string} Formatted price string, e.g. "1,234.56 GBP" or "-50.00 USD".
 */
const formatValueWithCurrencyHandler = (value, currency) => {
    const formattedPrice = formatFloatingPoint(value).format_price();
    if (!currency) {
        return formattedPrice;
    }
    if (!value) {
        return `0 ${currency}`;
    }
    if (!formattedPrice) {
        return `0 ${currency}`;
    }
    if (formattedPrice < 0) {
        return `-${-formattedPrice} ${currency}`;
    }
    return `${formattedPrice} ${currency}`;
};

/**
 * Formats a numeric value as a currency string. Thin wrapper around
 * `formatValueWithCurrencyHandler`, exposed via `acquisitionsActions`.
 *
 * @param {number|string|null} value    - The amount to format.
 * @param {string|null}        currency - ISO currency code to append, or null to omit.
 * @returns {string} Formatted price string.
 */
const formatValueWithCurrency = (value, currency) =>
    formatValueWithCurrencyHandler(value, currency);

/**
 * Transforms a flat fund array into a depth-annotated list for tree-select components.
 * Funds are ordered parents-before-children; each entry gains `_depth` and `_displayName`
 * properties. Funds whose `parent_fund_id` is not present in the array are treated as
 * top-level nodes.
 *
 * @param {Array<Object>|null|undefined} funds - Flat array of fund objects. Each must
 *   have `fund_id` and `name`; `parent_fund_id` is optional.
 * @returns {Array<Object>} Annotated fund objects with added `_depth` (number) and
 *   `_displayName` (string, prefixed with "└ " for non-root nodes) properties.
 */
const buildFundTreeOptions = funds => {
    if (!funds) return [];

    const fundIds = new Set(funds.map(fund => fund.fund_id));
    const childrenByParent = {};

    funds.forEach(fund => {
        const parentKey =
            fund.parent_fund_id && fundIds.has(fund.parent_fund_id)
                ? fund.parent_fund_id
                : null;
        (childrenByParent[parentKey] ??= []).push(fund);
    });

    const result = [];
    const addFundAndChildren = (fund, depth) => {
        result.push({
            ...fund,
            _depth: depth,
            _displayName: depth === 0 ? fund.name : "└ " + fund.name,
        });
        (childrenByParent[fund.fund_id] ?? []).forEach(child =>
            addFundAndChildren(child, depth + 1)
        );
    };

    (childrenByParent[null] ?? []).forEach(fund => addFundAndChildren(fund, 0));

    return result;
};

/**
 * Returns a validation config object for numeric form inputs.
 *
 * @param {Object}  [params]
 * @param {boolean} [params.positiveOnly=true] - When true, rejects negative values;
 *   when false, allows a leading minus sign.
 * @returns {{ formErrorHandler: Function, formErrorMessage: string }}
 *   `formErrorHandler` is a predicate that returns true when the value is valid;
 *   `formErrorMessage` is the i18n error string to display on failure.
 */
const applyNumberValidation = ({ positiveOnly = true } = {}) => ({
    formErrorHandler: value => {
        const pattern = positiveOnly
            ? /^\d*(\.\d{0,2})*$/
            : /^[\-]?\d*(\.\d{0,2})*$/;
        return pattern.test(value) && (!positiveOnly || Number(value) >= 0);
    },
    formErrorMessage: positiveOnly
        ? $__("Please enter a positive amount in valid format: 0.00")
        : $__("Please add amount in valid format: 0.00"),
});

/**
 * Composable that builds and opens an allocation modal for a fund or ledger.
 * Handles INCREASE, DECREASE, and TRANSFER actions, including live preview of the
 * resulting amount and server-side breach-amount validation.
 *
 * @param {Object}   params
 * @param {string}   params.entity                - "fund" or "ledger".
 * @param {Function} params.setConfirmationDialog - Store action that opens a confirmation modal.
 * @param {Function} params.setWarning            - Store action that displays a warning banner.
 * @param {Function} params.setMessage            - Store action that displays a success banner.
 * @param {Function} [params.onSuccess]           - Optional callback invoked after a successful
 *   allocation is created.
 * @returns {{ openAllocationModal: Function, getAllocationToolbarButtons: Function }}
 */
const useAllocationModal = ({
    entity,
    setConfirmationDialog,
    setWarning,
    setMessage,
    onSuccess,
}) => {
    const isFund = entity === "fund";
    const breachAmountMessage = $__(
        "The parent amount will be breached by %s. Please reduce the amount for this allocation."
    );

    /**
     * Opens the allocation dialog for the given resource and action type.
     * Fetches the latest entity data from the API before rendering the form.
     *
     * @param {Object} resource - The fund or ledger resource object; must contain the entity ID.
     * @param {string} action   - One of "increase", "decrease", or "transfer".
     */
    const openAllocationModal = (resource, action) => {
        const entityId = resource[entity + "_id"];
        const isIncrease = action === "increase";
        const isDecrease = action === "decrease";
        const isTransfer = action === "transfer";

        const title = isIncrease
            ? isFund
                ? $__("Increase fund amount")
                : $__("Increase ledger amount")
            : isDecrease
              ? isFund
                  ? $__("Decrease fund amount")
                  : $__("Decrease ledger amount")
              : isFund
                ? $__("Transfer fund amount")
                : $__("Transfer ledger amount");

        const allocationAmountLabel = isIncrease
            ? $__("Increase amount by")
            : isDecrease
              ? $__("Decrease amount by")
              : $__("Amount being transferred");

        const remainingAmountLabel = isIncrease
            ? isFund
                ? $__("Increased fund amount")
                : $__("Increased ledger amount")
            : isDecrease
              ? isFund
                  ? $__("Decreased fund amount")
                  : $__("Decreased ledger amount")
              : isFund
                ? $__("Remaining fund amount")
                : $__("Remaining ledger amount");

        APIClient.acquisition[entity + "s"].get(entityId).then(result => {
            const ledger = isFund ? result.ledger : result;
            const currency = ledger?.currency;
            const entityAmount = result[entity + "_amount"];
            const fiscalPeriodName = result.fiscal_period?.name;
            const ledgerName = ledger?.name;
            const fundName = isFund ? result.name : null;

            setConfirmationDialog(
                {
                    title,
                    accept_label: $__("Save"),
                    cancel_label: $__("Cancel"),
                    size: "modal-lg",
                    inputs: [
                        {
                            name: "fiscal_period_name",
                            type: "display",
                            label: $__("Fiscal period"),
                            defaultValue: fiscalPeriodName,
                        },
                        {
                            name: "ledger_name",
                            type: "display",
                            label: $__("Ledger"),
                            defaultValue: ledgerName,
                        },
                        ...(isFund
                            ? [
                                  {
                                      name: "fund_name",
                                      type: "display",
                                      label: $__("Fund"),
                                      defaultValue: fundName,
                                  },
                              ]
                            : []),
                        {
                            name: "current_amount",
                            type: "display",
                            label: $__("Current amount"),
                            defaultValue: formatValueWithCurrency(
                                entityAmount,
                                currency
                            ),
                        },
                        {
                            name: "allocation_amount",
                            type: "number",
                            label: allocationAmountLabel,
                            required: true,
                            ...applyNumberValidation(),
                        },
                        ...(isTransfer
                            ? [
                                  {
                                      name: "is_transferred_to",
                                      type: "relationshipSelect",
                                      label: isFund
                                          ? $__("Destination fund")
                                          : $__("Destination ledger"),
                                      relationshipAPIClient:
                                          APIClient.acquisition[
                                              isFund ? "funds" : "ledgers"
                                          ],
                                      relationshipOptionLabelAttr: "name",
                                      relationshipRequiredKey: isFund
                                          ? "fund_id"
                                          : "ledger_id",
                                      query: {
                                          [isFund ? "fund_id" : "ledger_id"]: {
                                              "!=": entityId,
                                          },
                                      },
                                      treeSelect: isFund,
                                      treeSelectOptionsHandler:
                                          buildFundTreeOptions,
                                      required: true,
                                  },
                              ]
                            : []),
                        {
                            name: "reference",
                            type: "text",
                            label: $__("Reference"),
                        },
                        {
                            name: "note",
                            type: "text",
                            label: $__("Note"),
                        },
                        {
                            name: "remaining_amount",
                            type: "display",
                            label: remainingAmountLabel,
                            format: (value, resource) => {
                                const allocated =
                                    parseFloat(resource.allocation_amount) || 0;
                                const remainder = isIncrease
                                    ? entityAmount + allocated
                                    : entityAmount - allocated;
                                resource.remaining_amount = remainder;
                                return formatValueWithCurrency(
                                    remainder,
                                    currency
                                );
                            },
                        },
                    ],
                },
                async (confirmation, inputFields) => {
                    const allocated =
                        parseFloat(inputFields.allocation_amount) || 0;
                    const remaining = isIncrease
                        ? entityAmount + allocated
                        : entityAmount - allocated;

                    if (remaining < 0) {
                        setWarning(
                            $__(
                                "Insufficient funds to process this transaction, please adjust the allocation amount"
                            )
                        );
                        return;
                    }

                    const allocation = {
                        allocation_amount: allocated,
                        type: action.toUpperCase(),
                        [entity + "_id"]: parseInt(entityId),
                        ...(isTransfer && inputFields.is_transferred_to
                            ? {
                                  is_transferred_to:
                                      inputFields.is_transferred_to,
                              }
                            : {}),
                        reference: inputFields.reference || null,
                        note: inputFields.note || null,
                    };

                    await APIClient.acquisition.allocations
                        .create(allocation)
                        .then(
                            () => {
                                setMessage($__("Allocation created"));
                                onSuccess?.();
                            },
                            error => {
                                setWarning(
                                    breachAmountMessage.format(
                                        formatValueWithCurrency(
                                            error.result.breach_amount
                                        )
                                    )
                                );
                            }
                        );
                }
            );
        });
    };

    const buttonConfigs = [
        {
            action: "increase",
            icon: "plus",
            title: isFund
                ? $__("Increase fund amount")
                : $__("Increase ledger amount"),
        },
        {
            action: "decrease",
            icon: "minus",
            title: isFund
                ? $__("Decrease fund amount")
                : $__("Decrease ledger amount"),
        },
        {
            action: "transfer",
            icon: "arrow-right-arrow-left",
            title: isFund
                ? $__("Transfer fund amount")
                : $__("Transfer ledger amount"),
        },
    ];

    const inactiveHint = isFund
        ? $__("This fund is inactive")
        : $__("This ledger is inactive");

    /**
     * Returns toolbar button configs for the three allocation actions (increase, decrease,
     * transfer). Buttons are disabled and carry a hint when the entity is inactive.
     *
     * @param {Object} resource - The fund or ledger resource object.
     * @returns {Array<Object>} Toolbar button config objects.
     */
    const getAllocationToolbarButtons = resource =>
        buttonConfigs.map(({ action, icon, title }) => ({
            onClick: () => openAllocationModal(resource, action),
            title,
            icon,
            disabled: !resource.status,
            hint: inactiveHint,
        }));

    return { openAllocationModal, getAllocationToolbarButtons };
};

/**
 * Composable that builds and opens a two-step ledger duplication modal.
 * Step 1 collects duplicate parameters; step 2 shows a dry-run preview before the
 * user confirms. Commits the duplicate via `APIClient.acquisition.ledgers.duplicate`.
 *
 * @param {Object}   params
 * @param {Function} params.setConfirmationDialog - Store action that opens a confirmation modal.
 * @param {Function} params.setWarning            - Store action that displays a warning banner.
 * @param {Function} params.setMessage            - Store action that displays a success banner.
 * @param {Function} [params.onSuccess]           - Optional callback invoked after a successful duplicate.
 * @returns {{ openDuplicateModal: Function }}
 */
const useDuplicateModal = ({
    setConfirmationDialog,
    setWarning,
    setMessage,
    onSuccess,
}) => {
    /**
     * Maps a subset of a resource's attribute definitions to dialog input configs,
     * applying optional field-level overrides and evaluating `format` functions for
     * display-type fields.
     *
     * @param {Object}     resource          - Current resource object used to read field values
     *   and run formatter functions.
     * @param {Array}      attrs             - Full resourceAttr definitions from the resource component.
     * @param {Object}     [overrides={}]    - Per-field config overrides merged on top of each attr.
     * @param {Array|null} [fieldsInOrder]   - Ordered list of field names to include. Defaults to a
     *   fixed ledger-field list when null.
     * @returns {Array<Object>} Dialog input config objects ready for `setConfirmationDialog`.
     */
    const buildInputsFromAttrs = (
        resource,
        attrs,
        overrides = {},
        fieldsInOrder = null
    ) => {
        const attrsByName = Object.fromEntries(attrs.map(a => [a.name, a]));
        const fields = fieldsInOrder || [
            "name",
            "description",
            "external_id",
            "status",
            "locked",
            "currency",
            "ledger_amount",
            "oe_warning_percent",
            "oe_warning_amount",
            "managing_branch",
            "owner_id",
        ];
        return fields.reduce((acc, name) => {
            const attr = attrsByName[name];
            if (!attr) return acc;
            const override = overrides[name] || {};
            const effectiveType = override.type ?? attr.type;
            const rawValue = resource[name];
            const { format, ...attrWithoutFormat } = attr;
            const defaultValue =
                effectiveType === "display" && format
                    ? format(rawValue, resource, attr)
                    : rawValue;
            acc.push({ ...attrWithoutFormat, defaultValue, ...override });
            return acc;
        }, []);
    };

    /**
     * Opens the duplication configuration dialog for the given ledger resource.
     * On confirmation, performs a dry-run duplication to generate a preview, then opens
     * a second dialog to confirm before committing via the API.
     *
     * @param {Object} resource      - The ledger resource object to roll over.
     * @param {Array}  resourceAttrs - The resource's attribute definitions, used to build form inputs.
     */
    const openDuplicateModal = (resource, resourceAttrs) => {
        const groups = [
            {
                label: $__("Information and status"),
                inputs: [
                    // {
                    //     name: "duplicate_warning",
                    //     type: "display",
                    //     label: $__("Warning"),
                    //     defaultValue: $__(
                    //         "The original ledger will be set to inactive on duplicate"
                    //     ),
                    // },
                    {
                        name: "fiscal_period_id",
                        type: "relationshipSelect",
                        label: $__("Fiscal period"),
                        relationshipAPIClient:
                            APIClient.acquisition.fiscalPeriods,
                        relationshipOptionLabelAttr: "name",
                        relationshipRequiredKey: "fiscal_period_id",
                        required: true,
                    },
                    ...buildInputsFromAttrs(
                        resource,
                        resourceAttrs,
                        { locked: { defaultValue: false } },
                        [
                            "name",
                            "description",
                            "external_id",
                            "status",
                            "locked",
                        ]
                    ),
                ],
            },
            {
                label: $__("Financial controlling"),
                inputs: [
                    ...buildInputsFromAttrs(
                        resource,
                        resourceAttrs,
                        {
                            currency: { type: "display" },
                            ledger_amount: { type: "display", toolTip: null },
                            oe_warning_amount: {
                                defaultValue: resource.oe_warning_amount,
                            },
                            oe_warning_percent: {
                                defaultValue: resource.oe_warning_percent,
                            },
                        },
                        [
                            "currency",
                            "ledger_amount",
                            "oe_warning_percent",
                            "oe_warning_amount",
                        ]
                    ),
                    {
                        name: "adjust_by_percent",
                        type: "number",
                        label: $__("Adjust the amounts by a percentage"),
                        ...applyNumberValidation({ positiveOnly: false }),
                    },
                    {
                        name: "round_to_multiple",
                        type: "number",
                        label: $__("Round to a multiple of"),
                        disabled: resource => !resource.adjust_by_percent,
                        toolTip: $__(
                            "If you entered a value in 'Change amounts by', Koha will calculate the amounts automatically. You can force it to round down the amounts. For example, entering '100', will round down the amounts to the hundreds (5542 will become 5500)."
                        ),
                        ...applyNumberValidation(),
                    },
                    {
                        name: "new_ledger_amount",
                        type: "display",
                        label: $__("New ledger amount"),
                        format: (value, fields) => {
                            const base = resource.ledger_amount || 0;
                            const percentage =
                                parseFloat(fields.adjust_by_percent) || 0;
                            const multiple =
                                parseFloat(fields.round_to_multiple) || 0;
                            let adjusted = base + (base * percentage) / 100;
                            if (multiple > 0) {
                                adjusted =
                                    Math.trunc(adjusted / multiple) * multiple;
                            }
                            return formatValueWithCurrency(
                                adjusted,
                                resource.currency
                            );
                        },
                    },
                    {
                        name: "set_funds_to_zero",
                        type: "checkbox",
                        label: $__("Set all funds to zero"),
                        toolTip: $__("All fund amounts will be set to 0"),
                    },
                ],
            },
            {
                label: $__("Management in library"),
                inputs: buildInputsFromAttrs(resource, resourceAttrs, {}, [
                    "managing_branch",
                    "owner_id",
                ]).map(attr =>
                    attr.name === "managing_branch"
                        ? {
                              ...attr,
                              componentProps: {
                                  ...attr.componentProps,
                                  routeAction: { type: "string", value: "add" },
                              },
                          }
                        : attr
                ),
            },
        ];

        setConfirmationDialog(
            {
                title: $__("Duplicate ledger and funds"),
                accept_label: $__("Preview duplication"),
                cancel_label: $__("Cancel"),
                size: "modal-lg",
                groups,
            },
            async (confirmation, inputFields) => {
                const body = {
                    fiscal_period_id: inputFields.fiscal_period_id,
                    name: inputFields.name,
                    description: inputFields.description || null,
                    external_id: inputFields.external_id || null,
                    status: inputFields.status,
                    locked: inputFields.locked ?? false,
                    currency: resource.currency,
                    ledger_amount: resource.ledger_amount || 0,
                    oe_warning_percent:
                        (inputFields.oe_warning_percent || 0) / 100,
                    oe_warning_amount: inputFields.oe_warning_amount || null,
                    managing_branch: inputFields.managing_branch || null,
                    owner_id: inputFields.owner_id || null,
                    adjust_by_percent: inputFields.adjust_by_percent || null,
                    round_to_multiple: inputFields.round_to_multiple || null,
                    set_funds_to_zero: inputFields.set_funds_to_zero || false,
                };

                const preview = await APIClient.acquisition.ledgers
                    .duplicate(resource.ledger_id, body, { dryRun: true })
                    .catch(() => {
                        setWarning(
                            $__("An error occurred during duplicate preview")
                        );
                        return null;
                    });

                if (!preview) return;

                const previewGroups = [
                    {
                        label: $__("New ledger"),
                        inputs: [
                            {
                                name: "preview_ledger_name",
                                type: "display",
                                label: $__("Name"),
                                defaultValue: preview.name,
                            },
                            {
                                name: "preview_ledger_amount",
                                type: "display",
                                label: $__("Amount"),
                                defaultValue: formatValueWithCurrency(
                                    preview.ledger_amount,
                                    preview.currency
                                ),
                            },
                        ],
                    },
                    {
                        label: $__("Funds to be created"),
                        inputs: (preview.funds || []).map(fund => ({
                            name: `preview_fund_${fund.fund_id}`,
                            type: "display",
                            label: fund.name,
                            defaultValue: formatValueWithCurrency(
                                fund.fund_amount,
                                preview.currency
                            ),
                        })),
                    },
                ];

                setConfirmationDialog(
                    {
                        title: $__("Confirm duplication"),
                        accept_label: $__("Confirm duplication"),
                        cancel_label: $__("Cancel"),
                        size: "modal-lg",
                        groups: previewGroups,
                    },
                    async () => {
                        await APIClient.acquisition.ledgers
                            .duplicate(resource.ledger_id, body)
                            .then(
                                () => {
                                    setMessage(
                                        $__("Ledger rolled over successfully")
                                    );
                                    onSuccess?.();
                                },
                                () => {
                                    setWarning(
                                        $__(
                                            "An error occurred during duplication"
                                        )
                                    );
                                }
                            );
                    }
                );
            }
        );
    };

    return { openDuplicateModal };
};

/**
 * Composable that builds and opens a two-step ledger rollover modal.
 * Step 1 collects the destination ledger and rollover options; step 2 shows a
 * dry-run preview before the user confirms. Commits the rollover via
 * `APIClient.acquisition.ledgers.rollover`.
 *
 * @param {Object}   params
 * @param {Function} params.setConfirmationDialog - Store action that opens a confirmation modal.
 * @param {Function} params.setWarning            - Store action that displays a warning banner.
 * @param {Function} params.setMessage            - Store action that displays a success banner.
 * @param {Function} [params.onSuccess]           - Optional callback invoked after a successful rollover.
 * @returns {{ openRolloverModal: Function }}
 */
const useRolloverModal = ({
    setConfirmationDialog,
    setWarning,
    setMessage,
    onSuccess,
}) => {
    /**
     * Opens the rollover configuration dialog for the given ledger resource.
     * On confirmation, performs a dry-run to generate a preview, then opens a
     * second dialog to confirm before committing via the API.
     *
     * @param {Object} resource - The ledger resource object to roll over.
     */
    const openRolloverModal = resource => {
        setConfirmationDialog(
            {
                title: $__("Rollover ledger"),
                accept_label: $__("Preview rollover"),
                cancel_label: $__("Cancel"),
                size: "modal-lg",
                groups: [
                    {
                        label: $__("Destination"),
                        inputs: [
                            {
                                name: "destination_ledger_id",
                                type: "relationshipSelect",
                                label: $__("Destination ledger"),
                                relationshipAPIClient:
                                    APIClient.acquisition.ledgers,
                                relationshipOptionLabelAttr: "name",
                                relationshipRequiredKey: "ledger_id",
                                required: true,
                                query: {
                                    ledger_id: { "!=": resource.ledger_id },
                                },
                            },
                            {
                                name: "move_unspent_funds",
                                type: "checkbox",
                                label: $__("Move unspent funds"),
                                toolTip: $__(
                                    "Transfer each fund's unspent balance to the matching destination fund"
                                ),
                            },
                        ],
                    },
                ],
            },
            async (confirmation, inputFields) => {
                const body = {
                    destination_ledger_id: inputFields.destination_ledger_id,
                    move_unspent_funds: inputFields.move_unspent_funds || false,
                };

                const preview = await APIClient.acquisition.ledgers
                    .rollover(resource.ledger_id, body, { dryRun: true })
                    .catch(() => {
                        setWarning(
                            $__("An error occurred during rollover preview")
                        );
                        return null;
                    });

                if (!preview) return;

                const allOrderlines = [
                    ...(preview.funds_matched || []).flatMap(f =>
                        (f.orderlines || []).map(ol => ({
                            fund: `${f.source_fund_name} → ${f.destination_fund_name}`,
                            ...ol,
                        }))
                    ),
                    ...(preview.funds_unmatched || []).flatMap(f =>
                        (f.orderlines || []).map(ol => ({
                            fund: `${f.source_fund_name} — ${$__("no matching fund")}`,
                            ...ol,
                        }))
                    ),
                ];

                const orderlinesInput = allOrderlines.length
                    ? {
                          name: "orderlines",
                          type: "component",
                          componentPath:
                              "@koha-vue/components/RelationshipTableDisplay.vue",
                          componentProps: {
                              tableOptions: {
                                  type: "object",
                                  value: {
                                      columns: [
                                          {
                                              title: $__("Fund"),
                                              data: "fund",
                                          },
                                          {
                                              title: $__("Orderline ID"),
                                              data: "orderline_id",
                                          },
                                          {
                                              title: $__("Title"),
                                              data: "title",
                                          },
                                          {
                                              title: $__("Purchase order"),
                                              data: "purchase_order_name",
                                          },
                                          {
                                              title: $__("Amount"),
                                              data: "amount",
                                              render: data =>
                                                  data != null
                                                      ? Number(data).toFixed(2)
                                                      : "—",
                                          },
                                      ],
                                      data: allOrderlines,
                                      actions: {},
                                      options: {
                                          paging: false,
                                          searching: false,
                                      },
                                  },
                              },
                          },
                      }
                    : {
                          name: "orderlines",
                          type: "display",
                          defaultValue: $__("No open orders"),
                      };

                setConfirmationDialog(
                    {
                        title: $__("Confirm rollover"),
                        accept_label: $__("Confirm rollover"),
                        cancel_label: $__("Cancel"),
                        size: "modal-lg",
                        inputs: [orderlinesInput],
                    },
                    async () => {
                        await APIClient.acquisition.ledgers
                            .rollover(resource.ledger_id, body)
                            .then(
                                () => {
                                    setMessage(
                                        $__("Ledger rolled over successfully")
                                    );
                                    onSuccess?.();
                                },
                                error => {
                                    setWarning(
                                        $__(
                                            "An error occurred while rolling over the ledger"
                                        )
                                    );
                                }
                            );
                    }
                );
            }
        );
    };

    return { openRolloverModal };
};

/**
 * Calculates and mutates all amount fields on a fund distribution object.
 *
 * If `distribution.percentage` is set, `distributed_amount_oc` is derived from
 * the orderline's `calculated_amount_oc` before any further calculations.
 * The FX-converted amount is then split into tax-included and tax-excluded
 * figures based on whether the vendor's list price already includes GST:
 *   - list_includes_gst=true:  tax is removed by dividing through (1 + tax_rate)
 *   - list_includes_gst=false: tax is added on top by multiplying by (1 + tax_rate)
 *
 * Mutated fields: `taxIncluded`, `distributed_amount_oc` (if percentage-driven),
 * `distributed_amount`, `distributed_amount_tax_included`,
 * `distributed_amount_tax_excluded`, `tax_value`.
 *
 * @param {Object} distribution - Fund distribution record to update in place.
 * @param {Object} orderLine    - Parent orderline providing price, vendor, and exchange rate context.
 */
const calculateDistributedAmount = (distribution, orderLine) => {
    const taxIncluded = orderLine.vendor?.list_includes_gst;
    distribution.taxIncluded = taxIncluded;
    const totalAmount = orderLine.calculated_amount_oc;

    if (distribution.percentage) {
        distribution.distributed_amount_oc = new BigNumber(totalAmount || 0)
            .times(distribution.percentage)
            .div(100)
            .toNumber();
    }

    const fxConverted = new BigNumber(
        distribution.distributed_amount_oc || 0
    ).times(distribution.exchange_rate || 0);

    if (taxIncluded) {
        const taxExcluded = fxConverted.div(
            new BigNumber(1).plus(distribution.tax_rate || 0)
        );
        distribution.distributed_amount_tax_included = fxConverted.toNumber();
        distribution.distributed_amount_tax_excluded = taxExcluded.toNumber();
        distribution.tax_value = fxConverted.minus(taxExcluded).toNumber();
    } else {
        const taxIncludedAmount = fxConverted.times(
            new BigNumber(1).plus(distribution.tax_rate || 0)
        );
        distribution.distributed_amount_tax_excluded = fxConverted.toNumber();
        distribution.distributed_amount_tax_included =
            taxIncludedAmount.toNumber();
        distribution.tax_value = taxIncludedAmount
            .minus(fxConverted)
            .toNumber();
    }
    distribution.distributed_amount = fxConverted.toNumber();
};

/**
 * Returns a RelationshipTableDisplay tab config for the allocations table.
 * Columns: Timestamp, Type, Amount, Reference, Note.
 *
 * @param {Object} params
 * @param {string} params.entity - "fund" or "ledger"; determines the filter key used to scope rows.
 * @returns {Object} Tab config object suitable for use in appendToShow.
 */
const useAllocationTableConfig = ({ entity }) => {
    const filterKey = entity + "_id";
    return {
        type: "component",
        name: $__("Allocations"),
        componentPath: "@koha-vue/components/RelationshipTableDisplay.vue",
        componentProps: {
            tableOptions: {
                type: "object",
                value: {
                    columns: [
                        {
                            title: $__("Timestamp"),
                            data: "created_date",
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                return $date(row.created_date, {
                                    withtime: true,
                                });
                            },
                        },
                        {
                            title: $__("Type"),
                            data: "type",
                            dataFilter: "type",
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                return (
                                    String(row.type).charAt(0).toUpperCase() +
                                    String(row.type).slice(1)
                                );
                            },
                        },
                        {
                            title: $__("Amount"),
                            data: "allocation_amount",
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                const isIncrease =
                                    row.type === "INCREASE" ||
                                    row.type === "INITIAL" ||
                                    row.type === "ROLLOVER_TRANSFER" ||
                                    (row.type === "TRANSFER" &&
                                        row.is_transferred_from);
                                const symbol = isIncrease ? "+" : "-";
                                const colour = isIncrease ? "green" : "red";
                                return (
                                    '<span style="color:' +
                                    colour +
                                    ';">' +
                                    symbol +
                                    formatValueWithCurrency(
                                        row.allocation_amount
                                    ) +
                                    "</span>"
                                );
                            },
                        },
                        {
                            title: $__("Reference"),
                            data: "reference",
                            searchable: true,
                            orderable: true,
                        },
                        {
                            title: $__("Note"),
                            data: "note",
                            searchable: true,
                            orderable: true,
                        },
                    ],
                    url:
                        APIClient.acquisition.httpClient._baseURL +
                        "allocations",
                    table_settings: null,
                    add_filters: true,
                    filters_options: {
                        type: [
                            { _id: "INITIAL", _str: $__("Initial") },
                            { _id: "INCREASE", _str: $__("Increase") },
                            { _id: "DECREASE", _str: $__("Decrease") },
                            { _id: "TRANSFER", _str: $__("Transfer") },
                            {
                                _id: "ROLLOVER_TRANSFER",
                                _str: $__("Rollover transfer"),
                            },
                        ],
                    },
                    actions: { 0: ["show"] },
                },
            },
            apiClient: {
                type: "object",
                value: APIClient.acquisition.allocations,
            },
            filters: {
                type: "filter",
                keys: {
                    [filterKey]: { property: filterKey },
                },
            },
        },
        resource: { type: "resource" },
        resourceName: { type: "string", value: "allocation" },
        resourceNamePlural: { type: "string", value: "allocations" },
    };
};

/**
 * Returns a RelationshipTableDisplay tab config for a funds or sub-funds table.
 * Columns: Name (linked via Vue Router), Code, Description, Amount, Status.
 *
 * @param {Object}   params
 * @param {string}   params.name               - Tab label shown in the UI.
 * @param {Function} [params.hidden]           - Optional predicate; tab is hidden when it returns truthy.
 * @param {string}   params.filterKey          - API filter parameter name (e.g. "ledger_id" or "parent_fund_id").
 * @param {string}   params.filterProperty     - Resource property used as the filter value (e.g. "ledger_id" or "fund_id").
 * @param {string}   params.resourceName       - Singular resource label (e.g. "fund" or "sub fund").
 * @param {string}   params.resourceNamePlural - Plural resource label (e.g. "funds" or "sub funds").
 * @param {boolean}  [params.tree]             - When true, render a tree table: only top-level funds
 *                                               are rows and their sub-funds appear as expandable child rows.
 * @param {Object}   params.router             - Vue Router instance used for navigation and href resolution.
 * @returns {Object} Tab config object suitable for use in appendToShow.
 */
const useFundTableConfig = ({
    name,
    hidden,
    filterKey,
    filterProperty,
    resourceName,
    resourceNamePlural,
    tree = null,
    router,
}) => ({
    type: "component",
    name,
    ...(hidden ? { hidden } : {}),
    componentPath: "@koha-vue/components/RelationshipTableDisplay.vue",
    componentProps: {
        tableOptions: {
            type: "object",
            value: {
                columns: [
                    {
                        title: $__("Name"),
                        data: "name:fund_id",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return (
                                '<a href="' +
                                router.resolve({
                                    name: "FundShow",
                                    params: { fund_id: row.fund_id },
                                }).href +
                                '" class="showFund">' +
                                escape_str(`${row.name}`) +
                                "</a>"
                            );
                        },
                    },
                    {
                        title: $__("Code"),
                        data: "code",
                        searchable: true,
                        orderable: true,
                    },
                    {
                        title: $__("Description"),
                        data: "description",
                        searchable: true,
                        orderable: true,
                    },
                    {
                        title: $__("Amount"),
                        data: "fund_amount",
                        searchable: true,
                        orderable: true,
                    },
                    {
                        title: $__("Status"),
                        data: "status",
                        dataFilter: "status",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return row.status ? $__("Active") : $__("Inactive");
                        },
                    },
                ],
                url: APIClient.acquisition.httpClient._baseURL + "funds",
                table_settings: null,
                add_filters: true,
                ...(tree && { options: { embed: tree.childrenField }, tree }),
                filters_options: {
                    status: [
                        { _id: 1, _str: $__("Active") },
                        { _id: 0, _str: $__("Inactive") },
                    ],
                },
                actions: {
                    [tree ? 1 : 0]: [
                        {
                            showFund: {
                                callback: (fund, dt, event) => {
                                    event?.preventDefault();
                                    router.push({
                                        name: "FundShow",
                                        params: { fund_id: fund.fund_id },
                                    });
                                },
                            },
                        },
                    ],
                },
            },
        },
        apiClient: {
            type: "object",
            value: APIClient.acquisition.funds,
        },
        filters: {
            type: "filter",
            keys: {
                [filterKey]: { property: filterProperty },
                ...(tree && { parent_fund_id: { value: null } }),
            },
        },
        resource: { type: "resource" },
        resourceName: { type: "string", value: resourceName },
        resourceNamePlural: { type: "string", value: resourceNamePlural },
    },
});

/**
 * Factory that returns the acquisitions store action map, injected into components
 * via `inject("acquisitionsStore")`.
 *
 * Exposed members: `formatValueWithCurrency`, `buildFundTreeOptions`,
 * `applyNumberValidation`, `useAllocationModal`, `useDuplicateModal`, `useRolloverModal`,
 * `useAllocationTableConfig`, `useFundTableConfig`, `calculateDistributedAmount`.
 *
 * @param {Object} store - The Pinia store instance (currently unused; reserved for future use).
 * @returns {Object} Map of acquisition utility functions and composables.
 */
export const acquisitionsActions = store => {
    return {
        formatValueWithCurrency,
        buildFundTreeOptions,
        applyNumberValidation,
        useAllocationModal,
        useDuplicateModal,
        useRolloverModal,
        useAllocationTableConfig,
        useFundTableConfig,
        calculateDistributedAmount,
    };
};
