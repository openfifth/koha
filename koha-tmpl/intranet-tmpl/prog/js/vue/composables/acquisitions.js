import { BigNumber } from "bignumber.js";

BigNumber.config({ DECIMAL_PLACES: 6 });

const formatFloatingPoint = value => {
    return new BigNumber(String(value ?? 0))
        .decimalPlaces(2, BigNumber.ROUND_HALF_UP)
        .toNumber();
};

const formatValueWithCurrencyHandler = (value, currency, store) => {
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

export const acquisitionsActions = store => {
    return {
        formatValueWithCurrency(value, currency) {
            return formatValueWithCurrencyHandler(value, currency, store);
        },
        buildFundTreeOptions,
    };
};
