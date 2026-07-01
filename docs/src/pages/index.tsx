import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/introduction">
            Get Started →
          </Link>
        </div>
      </div>
    </header>
  );
}

function Feature({title, description}: {title: string; description: string}) {
  return (
    <div className={styles.feature}>
      <h3>{title}</h3>
      <p>{description}</p>
    </div>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="Local LLM orchestration for Apple Silicon — native macOS app for serving MLX models with a smart reverse proxy.">
      <HomepageHeader />
      <main className={styles.features}>
        <div className="container">
          <div className={styles.featureGrid}>
            <Feature title="Local MLX" description="Load and serve MLX models with one click. Each model runs as an isolated process." />
            <Feature title="Smart Gateway" description="Unified API endpoint speaking OpenAI and Anthropic formats. Auto-routes by model prefix." />
            <Feature title="One-Click Integrations" description="Auto-configure VS Code, Claude Desktop, OpenCode, Codex, and 10+ other tools." />
            <Feature title="BYOK" description="Bring your own API keys for OpenAI, Anthropic, Gemini, OpenRouter, Groq, and Together AI." />
            <Feature title="Free Router" description="Route unrecognized models through OpenRouter as a cost-effective fallback." />
            <Feature title="Session Stickiness" description="Multi-turn conversations stay on the same backend — no dropped context." />
          </div>
        </div>
      </main>
    </Layout>
  );
}
