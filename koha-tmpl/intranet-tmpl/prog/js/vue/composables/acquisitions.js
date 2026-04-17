import { BigNumber } from "bignumber.js";

BigNumber.config({ DECIMAL_PLACES: 6 });

const formatFloatingPoint = value => {
    return new BigNumber(value).decimalPlaces(6).toNumber();
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

export const acquisitionsActions = store => {
    return {
        formatFloatingPoint,
        formatValueWithCurrency(value, currency) {
            return formatValueWithCurrencyHandler(value, currency, store);
        },
    };
};
