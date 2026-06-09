const VARIABLE_REGEX = /\{\{([^}]+)\}\}/g;

export const NAMED_VARIABLE_REGEX = /^[a-z][a-z0-9_]*$/;

export const extractVariablesInOrder = text => {
  if (!text?.trim()) return [];

  const variables = [];
  const seen = new Set();

  [...text.matchAll(VARIABLE_REGEX)].forEach(([, variable]) => {
    const name = variable.trim();
    if (!seen.has(name)) {
      seen.add(name);
      variables.push(name);
    }
  });

  return variables;
};

export const detectParameterFormat = variables => {
  if (!variables.length) return null;

  const positional = variables.every(variable => /^\d+$/.test(variable));
  if (positional) return 'POSITIONAL';

  const named = variables.every(variable =>
    NAMED_VARIABLE_REGEX.test(variable)
  );
  if (named) return 'NAMED';

  return 'MIXED';
};
