import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.ikebana.app',
  appName: '插花的艺术',
  webDir: 'dist',
  server: {
    // Use local dev server in development, bundle in production
    // url: 'http://172.20.10.2:5174/',
    // cleartext: true,
  },
  ios: {
    contentInset: 'always',
    scheme: 'Ikeana',
  },
}

export default config
