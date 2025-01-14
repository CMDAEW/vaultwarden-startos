import { sdk } from './sdk'
import { exposedStore } from './store'
import { setDependencies } from './dependencies'
import { setInterfaces } from './interfaces'
import { versions } from './versions'
import { actions } from './actions'
import { setAdminToken } from './actions/admin-token'
import { getHttpInterfaceUrls } from './utils'

// **** Install ****
const install = sdk.setupInstall(async ({ effects }) => {
  await sdk.action.requestOwn(effects, setAdminToken, 'critical')

  const urls = await getHttpInterfaceUrls(effects)

  await sdk.store.setOwn(
    effects,
    sdk.StorePath.DOMAIN,
    urls.find((u) => u.startsWith('http:') && u.includes('.onion')) || '',
  )
})

// **** Uninstall ****
const uninstall = sdk.setupUninstall(async ({ effects }) => {})

/**
 * Plumbing. DO NOT EDIT.
 */
export const { packageInit, packageUninit, containerInit } = sdk.setupInit(
  versions,
  install,
  uninstall,
  setInterfaces,
  setDependencies,
  actions,
  exposedStore,
)
