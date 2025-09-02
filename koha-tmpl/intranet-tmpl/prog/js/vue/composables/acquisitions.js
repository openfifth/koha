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
    const { symbol } = store.currencies.find(
        curr => curr.currency === currency
    );
    if (!value) {
        return `${symbol}0`;
    }
    if (!formattedPrice) {
        return `${symbol}0`;
    }
    if (formattedPrice < 0) {
        return `-${symbol}${-formattedPrice}`;
    }
    return `${symbol}${formattedPrice}`;
};

export const acquisitionsActions = store => {
    return {
        formatFloatingPoint,
        formatValueWithCurrency(value, currency) {
            return formatValueWithCurrencyHandler(value, currency, store);
        },
    };
};
