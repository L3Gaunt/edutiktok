const path = require('path');
const webpack = require('webpack');
const TerserPlugin = require('terser-webpack-plugin');

module.exports = {
  entry: './public/client.js',
  output: {
    filename: 'bundle.min.js',
    path: path.resolve(__dirname, 'public/dist'),
  },
  mode: 'production',
  optimization: {
    minimize: true,
    minimizer: [new TerserPlugin({
      terserOptions: {
        compress: {
          drop_console: false, // Keep console.logs for debugging
        },
      },
    })],
  },
  resolve: {
    fallback: {
      "buffer": require.resolve("buffer/"),
      "events": require.resolve("events/"),
    }
  },
  plugins: [
    new webpack.ProvidePlugin({
      Buffer: ['buffer', 'Buffer'],
      process: 'process/browser',
    }),
  ]
}; 