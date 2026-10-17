"use strict";

const MIN_FUNDING_AMOUNT_KOBO = 50000;
const MAX_FUNDING_AMOUNT_KOBO = 100000000;
const FUNDING_PRESET_AMOUNTS_KOBO = Object.freeze([
  50000,
  100000,
  200000,
  500000,
  1000000,
]);

function isValidFundingAmount(amountKobo) {
  return Number.isSafeInteger(amountKobo) &&
    amountKobo >= MIN_FUNDING_AMOUNT_KOBO &&
    amountKobo <= MAX_FUNDING_AMOUNT_KOBO;
}

module.exports = {
  MIN_FUNDING_AMOUNT_KOBO,
  MAX_FUNDING_AMOUNT_KOBO,
  FUNDING_PRESET_AMOUNTS_KOBO,
  isValidFundingAmount,
};
