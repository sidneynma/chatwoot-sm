import { findComponentByType } from 'dashboard/helper/templateHelper';

const COMPONENT_TYPES = {
  HEADER: 'HEADER',
  BODY: 'BODY',
  FOOTER: 'FOOTER',
  BUTTONS: 'BUTTONS',
};

export const getTemplateHeader = template => {
  const header = findComponentByType(template, COMPONENT_TYPES.HEADER);
  if (!header) return '';

  if (header.format && header.format !== 'TEXT') {
    return header.format;
  }

  return header.text || '';
};

export const getTemplateBody = template =>
  findComponentByType(template, COMPONENT_TYPES.BODY)?.text || '';

export const getTemplateFooter = template =>
  findComponentByType(template, COMPONENT_TYPES.FOOTER)?.text || '';

export const getTemplateButtons = template => {
  const buttonsComponent = findComponentByType(
    template,
    COMPONENT_TYPES.BUTTONS
  );
  if (!buttonsComponent?.buttons?.length) return '';

  return buttonsComponent.buttons.map(button => button.text).join(', ');
};

export const getTemplateComponents = template =>
  template.components?.map(component => component.type).join(', ') || '';
