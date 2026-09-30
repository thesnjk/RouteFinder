/** Vite `?worker&url` import returns a URL string for the bundled worker. */
declare module '*?worker&url' {
  const workerUrl: string
  export default workerUrl
}
