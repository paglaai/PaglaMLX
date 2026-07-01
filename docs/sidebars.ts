import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    'introduction',
    'installation',
    'getting-started',
    {
      type: 'category',
      label: 'Configuration',
      items: [
        'configuration/python',
        'configuration/network',
        'configuration/cloud-byok',
        'configuration/presets-personas',
      ],
    },
    'integrations',
    {
      type: 'category',
      label: 'API Reference',
      items: [
        'api-reference/chat-completions',
        'api-reference/messages',
        'api-reference/models',
        'api-reference/routing',
      ],
    },
    'architecture',
    'building',
    'troubleshooting',
  ],
};

export default sidebars;
