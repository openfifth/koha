import { BigNumber } from "bignumber.js";
import { APIClient } from "../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

BigNumber.config({ DECIMAL_PLACES: 6 });

const formatFloatingPoint = value => {
    return new BigNumber(String(value ?? 0))
        .decimalPlaces(2, BigNumber.ROUND_HALF_UP)
        .toNumber();
};

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

const formatValueWithCurrency = (value, currency) =>
    formatValueWithCurrencyHandler(value, currency);

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

const useRolloverModal = ({
    setConfirmationDialog,
    setWarning,
    setMessage,
    onSuccess,
}) => {
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

    const openRolloverModal = (resource, resourceAttrs) => {
        const groups = [
            {
                label: $__("Information and status"),
                inputs: [
                    {
                        name: "rollover_warning",
                        type: "display",
                        label: $__("Warning"),
                        defaultValue: $__(
                            "The original ledger will be set to inactive on rollover"
                        ),
                    },
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
                accept_label: $__("Preview rollover"),
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
                    .rollover(resource.ledger_id, body, { dryRun: true })
                    .catch(() => {
                        setWarning(
                            $__("An error occurred during rollover preview")
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
                        title: $__("Confirm rollover"),
                        accept_label: $__("Confirm rollover"),
                        cancel_label: $__("Cancel"),
                        size: "modal-lg",
                        groups: previewGroups,
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
                                () => {
                                    setWarning(
                                        $__("An error occurred during rollover")
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

export const acquisitionsActions = store => {
    return {
        formatValueWithCurrency,
        buildFundTreeOptions,
        applyNumberValidation,
        useAllocationModal,
        useRolloverModal,
        calculateDistributedAmount,
    };
};
