const BODY_VAR_RE = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g;

export const extractBodyText = template => {
  const body = (template?.components || []).find(
    c => (c.type || '').toUpperCase() === 'BODY'
  );
  return body?.text || '';
};

export const extractHeaderComponent = template => {
  return (template?.components || []).find(
    c => (c.type || '').toUpperCase() === 'HEADER'
  );
};

export const extractFooterText = template => {
  const footer = (template?.components || []).find(
    c => (c.type || '').toUpperCase() === 'FOOTER'
  );
  return footer?.text || '';
};

export const extractEvolutionVariableKeys = text => {
  const keys = [];
  const source = text || '';
  BODY_VAR_RE.lastIndex = 0;
  let match = BODY_VAR_RE.exec(source);
  while (match) {
    if (!keys.includes(match[1])) keys.push(match[1]);
    match = BODY_VAR_RE.exec(source);
  }
  BODY_VAR_RE.lastIndex = 0;
  return keys;
};

export const extractVariableKeys = template => {
  const text = extractBodyText(template);
  return extractEvolutionVariableKeys(text);
};

export const isAutoContactVar = key =>
  ['nome', 'name', '1'].includes(String(key || '').toLowerCase());

export const isAutoAgentVar = key =>
  ['agent', 'agente', 'agent_name'].includes(String(key || '').toLowerCase());

export const renderPreviewText = (text, bodyParams = {}, agentName = '') => {
  const vars = {
    nome: bodyParams.nome || bodyParams.name || 'Maria',
    name: bodyParams.name || bodyParams.nome || 'Maria',
    1: bodyParams['1'] || 'Maria',
    agent: agentName || bodyParams.agent || 'Agente',
    agente: agentName || bodyParams.agente || 'Agente',
    agent_name: agentName || bodyParams.agent_name || 'Agente',
    ...bodyParams,
  };

  return String(text || '').replace(
    /\{\{\s*([^}]+)\s*\}\}/g,
    (match, rawKey) => {
      const key = String(rawKey).trim();
      const value = vars[key];
      if (
        value !== undefined &&
        value !== null &&
        String(value).trim() !== ''
      ) {
        return String(value);
      }
      return match;
    }
  );
};

export const buildTemplateMetadata = ({
  template,
  bodyParams = {},
  headerMediaUrl = '',
  headerMediaType = '',
  headerMediaName = '',
  dispatchMode = 'meta_direct',
  inboxName = '',
  agentName = '',
}) => {
  const variableKeys = extractVariableKeys(template);
  const header = extractHeaderComponent(template);
  const headerFormat = (header?.format || '').toUpperCase();
  const processedHeader = {};

  if (['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerFormat) && headerMediaUrl) {
    processedHeader.media_url = headerMediaUrl;
    processedHeader.media_type = (
      headerMediaType || headerFormat.toLowerCase()
    ).toLowerCase();
    if (headerMediaName) processedHeader.media_name = headerMediaName;
  }

  return {
    dispatch_mode: dispatchMode,
    inbox_name: inboxName,
    agent_name: agentName,
    template: {
      name: template.name,
      language: template.language,
      namespace: template.namespace || '',
      category: template.category || 'UTILITY',
      status: template.status,
      components: template.components || [],
      body_text: extractBodyText(template),
      variable_keys: variableKeys,
      processed_params: {
        body: bodyParams,
        header: processedHeader,
      },
    },
  };
};

export const buildEvolutionMetadata = ({
  inboxName = '',
  agentName = '',
  mediaUrl = '',
  mediaType = '',
  mediaFilename = '',
  mediaName = '',
  delaySeconds = 15,
  bodyParams = {},
  variableKeys = [],
}) => {
  const metadata = {
    dispatch_mode: 'evolution',
    inbox_name: inboxName,
    agent_name: agentName,
    evolution_delay_seconds: Number(delaySeconds) || 15,
    evolution_instance: inboxName,
    variable_keys: variableKeys,
    template: {
      processed_params: {
        body: bodyParams,
      },
    },
  };

  if (mediaUrl) {
    metadata.media = {
      media_url: mediaUrl,
      media_type: mediaType || 'image',
      filename: mediaFilename || undefined,
      media_name: mediaName || undefined,
    };
  }

  return metadata;
};

export const normalizePhoneDigits = phone =>
  String(phone || '').replace(/\D/g, '');

export const parseRecipientsText = (
  text,
  variableKeys = [],
  extrasByPhone = {}
) =>
  text
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => {
      const parts = line
        .split(/[;,]/)
        .map(p => p.trim())
        .filter(Boolean);
      if (!parts.length) return null;

      let name = '';
      let phone = '';
      let varStart = 1;

      if (parts.length === 1) {
        phone = parts[0].replace(/\D/g, '');
      } else if (
        /^\d+$/.test(parts[0].replace(/\D/g, '')) &&
        parts[0].replace(/\D/g, '').length >= 10
      ) {
        phone = parts[0].replace(/\D/g, '');
        name = parts[1] || '';
        varStart = 2;
      } else {
        name = parts[0];
        phone = (parts[1] || '').replace(/\D/g, '');
        varStart = 2;
      }

      if (!phone) return null;

      const body = {};
      variableKeys.forEach((key, index) => {
        const value = parts[varStart + index];
        if (value) body[key] = value;
      });
      if (
        name &&
        (variableKeys.includes('nome') || variableKeys.includes('name'))
      ) {
        body.nome = body.nome || name;
        body.name = body.name || name;
      }

      const extras = extrasByPhone[phone] || extrasByPhone[`+${phone}`] || {};

      return {
        name,
        phone,
        contact_id: extras.contact_id || undefined,
        conversation_id: extras.conversation_id || undefined,
        metadata: Object.keys(body).length ? { template_params: { body } } : {},
      };
    })
    .filter(Boolean);

export const csvVarKeysForExport = (variableKeys = []) =>
  (variableKeys || []).filter(
    key => !isAutoContactVar(key) && !isAutoAgentVar(key)
  );

export const buildCsvModel = (variableKeys = []) => {
  const keys = csvVarKeysForExport(variableKeys);
  const headers = ['telefone', 'nome', ...keys];
  const row1 = ['+5511999998888', 'Maria'];
  const row2 = ['+5511888887777', 'Joao'];
  keys.forEach((_, idx) => {
    row1.push(`Exemplo${idx + 1}`);
    row2.push(`Valor${idx + 1}`);
  });
  return `\uFEFF${[headers.join(','), row1.join(','), row2.join(',')].join('\n')}\n`;
};

const splitCsvLine = (line, delimiter) => {
  const result = [];
  let cur = '';
  let inQ = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') {
      if (inQ && line[i + 1] === '"') {
        cur += '"';
        i += 1;
      } else {
        inQ = !inQ;
      }
    } else if (ch === delimiter && !inQ) {
      result.push(cur.trim());
      cur = '';
    } else {
      cur += ch;
    }
  }
  result.push(cur.trim());
  return result;
};

export const csvToRecipientLines = (text, variableKeys = []) => {
  const lines = String(text || '')
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .filter(l => l.trim());
  if (!lines.length) return [];

  const delimiter =
    (lines[0].match(/;/g) || []).length > (lines[0].match(/,/g) || []).length
      ? ';'
      : ',';
  const headers = splitCsvLine(lines[0], delimiter).map(h =>
    h
      .toLowerCase()
      .replace(/^\ufeff/, '')
      .trim()
  );

  let phoneIdx = headers.indexOf('telefone');
  if (phoneIdx < 0) phoneIdx = headers.indexOf('phone');
  let nameIdx = headers.indexOf('nome');
  if (nameIdx < 0) nameIdx = headers.indexOf('name');
  if (phoneIdx < 0) {
    throw new Error('CSV_NEEDS_PHONE');
  }

  const out = [];
  for (let r = 1; r < lines.length; r += 1) {
    const cols = splitCsvLine(lines[r], delimiter);
    const phone = cols[phoneIdx] || '';
    if (phone) {
      const parts = [phone, nameIdx >= 0 ? cols[nameIdx] || '' : ''];
      (variableKeys || []).forEach(key => {
        if (isAutoContactVar(key) || isAutoAgentVar(key)) {
          parts.push('');
          return;
        }
        const idx = headers.indexOf(String(key).toLowerCase());
        parts.push(idx >= 0 ? cols[idx] || '' : '');
      });
      out.push(parts.join(','));
    }
  }
  return out;
};

export const appendRecipientLines = (currentText, lines = []) => {
  const current = String(currentText || '').trim();
  const block = (lines || []).filter(Boolean).join('\n');
  if (!block) return current;
  return current ? `${current}\n${block}` : block;
};

export const formatPhoneForLine = phone => {
  const digits = normalizePhoneDigits(phone);
  if (!digits) return '';
  return digits.startsWith('55') || digits.startsWith('+')
    ? `+${digits.replace(/^\+/, '')}`
    : `+${digits}`;
};
