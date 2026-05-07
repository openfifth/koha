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
                            value: fiscalPeriodName,
                        },
                        {
                            name: "ledger_name",
                            type: "display",
                            label: $__("Ledger"),
                            value: ledgerName,
                        },
                        ...(isFund
                            ? [
                                  {
                                      name: "fund_name",
                                      type: "display",
                                      label: $__("Fund"),
                                      value: fundName,
                                  },
                              ]
                            : []),
                        {
                            name: "current_amount",
                            type: "display",
                            label: $__("Current amount"),
                            value: formatValueWithCurrency(
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

export const acquisitionsActions = store => {
    return {
        formatValueWithCurrency,
        buildFundTreeOptions,
        applyNumberValidation,
        useAllocationModal,
    };
};
