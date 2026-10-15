// Downgrade one class of breaking change to dangerous.
// A removed field, enum value, or input field that is already @deprecated.
// Inspector 7.0.1's built-in rule also marks every removed type as dangerous.
// This file does not do that. A removed type stays breaking.

const deprecatedRemoval = {
  FIELD_REMOVED: "isRemovedFieldDeprecated",
  ENUM_VALUE_REMOVED: "isEnumValueDeprecated",
  INPUT_FIELD_REMOVED: "isInputFieldDeprecated",
}

export default function suppressRemovalOfDeprecatedField({ changes }) {
  return changes.map((change) => {
    const flag = deprecatedRemoval[change.type]
    if (!flag || change.criticality?.level !== "BREAKING" || !change.meta?.[flag]) {
      return change
    }
    return {
      ...change,
      criticality: {
        ...change.criticality,
        level: "DANGEROUS",
      },
    }
  })
}
