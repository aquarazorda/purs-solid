import { configureClientErrors, resetErrorHalt as solidResetErrorHalt } from "solid-js";
import { configureServerErrors, isSafeError, markSafeError } from "@solidjs/web";

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

export const configureClientErrorsImpl = (onError) =>
  configureClientErrors({ onError: (error) => onError(toError(error))() });

export const configureServerErrorsImpl = (onError) =>
  configureServerErrors({
    onError: (error) => {
      onError(toError(error))();
    },
  });

export const resetErrorHalt = () => {
  solidResetErrorHalt();
};

export { isSafeError as isSafeErrorImpl, markSafeError as markSafeErrorImpl };
