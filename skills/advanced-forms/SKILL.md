---
name: advanced-forms
description: Implement advanced form patterns including multi-step wizards, async validation, cross-field validation, progressive validation, conditional fields, and form state persistence
metadata:
  version: 1.5
  argument-hint: "form type (multi-step/async validation/cross-field/conditional), framework (React/Vue/Angular), validation library (Zod/Yup/Valibot), persistence requirement (session/local storage)"
---

Implement $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs for current react-hook-form, Zod, Angular Reactive Forms, and framework-specific form docs. Do not rely on training data for library API syntax.

## Multi-Step Wizard Pattern

Model wizard state explicitly — never rely on step index alone.

```typescript
interface WizardState {
  currentStep: number;
  totalSteps: number;
  completedSteps: Set<number>;
  stepData: Record<number, Record<string, unknown>>;
  direction: 'forward' | 'backward';
  status: 'idle' | 'validating' | 'submitting' | 'error' | 'complete';
}
```

Rules:
- Each step has its own validation schema — validate only the current step on "Next"
- Validate all steps on final submission
- Allow backward navigation without validation
- Persist step data independently so going back does not lose later step data
- Show a progress indicator with step labels, not just dots

### React: react-hook-form + Zod

Use per-step `zodResolver`. Call `methods.trigger()` before advancing. Use `FormProvider` for nested step components. Use `methods.getValues()` to accumulate data across steps.

### Angular / Vue / Svelte

Same state-machine approach: per-step schema, validate before advancing, share data via parent ref or store. Angular: signal-based `currentStep`, per-step `FormGroup` array. Call `markAllAsTouched()` before advancing.

## Form State Persistence

Save draft to `sessionStorage` (sensitive forms) or `localStorage` (long-lived drafts).

Rules:
- Never persist passwords or credit card numbers
- Clear draft on successful submission
- Show "resume draft" prompt when returning to a form with stored data
- Include "discard draft" action

> Use available docs lookup tools or official docs to fetch current react-hook-form `watch` subscription docs for the persistence pattern.

## Async Validation

Debounce 300-500ms. Cancel previous requests on input change (AbortController / switchMap).

Rules:
- Show a loading indicator on the field during validation
- Validate only after sync schema passes — do not fire async checks on empty/malformed input
- Handle network errors gracefully — do not block form submission if the check fails
- React: use `setError`/`clearErrors` from react-hook-form with a debounced callback
- Angular: `AsyncValidatorFn` with `timer(500).pipe(switchMap(...), catchError(() => of(null)))` and `updateOn: 'blur'`

## Cross-Field Validation

```typescript
// Zod: cross-field with .refine() or .superRefine()
const passwordSchema = z.object({
  password: z.string().min(8),
  confirmPassword: z.string(),
}).refine(data => data.password === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
});

// Conditional required via discriminated union
const accountSchema = z.discriminatedUnion('accountType', [
  z.object({ accountType: z.literal('personal'), name: z.string().min(2) }),
  z.object({ accountType: z.literal('business'), name: z.string().min(2), companyName: z.string().min(1) }),
]);
```

Angular: apply a `ValidatorFn` to the `FormGroup` level.

## Progressive Validation

Validate on blur first. After a field has an error, switch to validating on change for immediate feedback.

- React: `mode: 'onTouched'` in react-hook-form — validates on blur, then on change after first error
- Angular: `updateOn: 'blur'` per control; `updateOn: 'submit'` on group for submit-only

Never show errors on untouched fields. On submit, validate all fields and focus the first error.

## Conditional Fields

Rules:
- Remove hidden fields from validation — do not validate invisible fields
- Clear or preserve hidden field values based on UX intent
- Keep form schema in sync with visible fields — use Zod discriminated unions or dynamic schemas
- Angular: call `setValidators()` + `updateValueAndValidity()` when conditional fields toggle

## File Upload Within Forms

Rules:
- Validate file type and size on client before uploading
- Show preview for images, filename + icon for documents
- Store the uploaded file URL in a hidden field — form submits the URL, not the file
- Handle upload failure with retry option
- Disable form submission while files are uploading

## Array / Repeatable Fields

Rules:
- Always key repeatable items by a stable ID (`field.id` from `useFieldArray`)
- Enforce min/max count with clear messaging
- Validate each item independently and show errors per item
- Support reorder via drag-and-drop or move up/down buttons

> Use available docs lookup tools or official docs to fetch current react-hook-form `useFieldArray` docs.

## Form Error Recovery

Rules:
- Never clear form fields on server error
- Map server validation errors to specific form fields when possible
- Show a general error banner for non-field errors
- Disable submit button during submission to prevent duplicates
- Re-enable and focus the first errored field on failure

## Schema-Driven Forms

Use `z.describe()` to store labels and hints in the schema. Derive TypeScript types with `z.infer<typeof schema>` — never duplicate. Keep schemas in dedicated files when shared between form and API validation. Use discriminated unions for forms with conditional sections.

## Accessibility

- Every input has a visible `<label>` or `aria-label`
- Error messages associated via `aria-describedby`
- Invalid fields marked with `aria-invalid="true"`
- Required fields have `aria-required="true"`
- Related fields grouped with `<fieldset>` + `<legend>`
- On submit with errors, focus the first field with an error
- On step change in a wizard, focus the first field of the new step
- Announce step changes to screen readers with `aria-live`

## Performance

- react-hook-form: uncontrolled inputs by default — do not switch to controlled unless required
- Watch only specific fields, not the entire form
- Angular: use `updateOn: 'blur'` for expensive validation; avoid method calls in templates

## Anti-Patterns

- Validating on every keystroke without debounce
- Showing errors on untouched fields
- Clearing form data on submission error
- Hidden fields still being validated
- No loading state during async validation or submission
- Wizard that cannot go backward
- Formik in new projects — prefer react-hook-form

## Implementation Workflow

1. Detect framework and existing form patterns
2. Define the form schema with Zod (or framework-native validators for Angular)
3. Identify field types: simple, conditional, async-validated, array/repeatable, file upload
4. Choose form library; implement progressive validation
5. Add async validation with debounce
6. Add cross-field and conditional field handling
7. Add form state persistence if long or multi-step
8. Handle submission with error recovery and server error mapping
9. Verify accessibility: labels, aria-describedby, focus management, announcements

## Done Criteria

- All fields validate with clear error messages using progressive validation
- Async validation debounced and cancellable with loading indicator
- Cross-field validation shows errors on the correct dependent field
- Conditional fields remove hidden field validation
- File uploads validated, previewed, and submitted as URL
- Array fields keyed by stable ID with per-item validation
- Submission guards against duplicates; server errors mapped to fields
- Accessibility: labels, aria-invalid, aria-describedby, focus management
