const HtmlWebpackPlugin = require('html-webpack-plugin');
const path = require('path');

module.exports = {
    entry: './src/index.js',
    mode: 'development',
    output: {
        path: path.resolve(__dirname, './dist'),
        filename: 'index_bundle.js',
    },
    target: 'web',
    devServer: {
        port: '3000',
        static: {
            directory: path.join(__dirname, 'public')
        },
        open: true,
        hot: true,
        liveReload: true,
    },
    resolve: {
        extensions: ['.js', '.jsx', '.json'],
        fallback: {
            // "zlib": require.resolve("browserify-zlib"),
            // "querystring": require.resolve("querystring-es3"),
            // "path": require.resolve("path-browserify"),
            // "crypto": require.resolve("crypto-browserify"),
            // "assert": require.resolve("assert/"),
            // "buffer": require.resolve("buffer/"),
            // "stream": require.resolve("stream-browserify"),
            // "util": require.resolve("util/"),
            // "http": require.resolve("stream-http"),
            // "async_hooks": false,
            // "fs": false,
        }
    },
    module: {
        rules: [
            {
                test: /\.(js|jsx)$/,
                exclude: /node_modules/,
                use: 'babel-loader',
            },
            {
                test: /\.css$/,
                use: [
                    'css-loader',
                ]
            },
            {
                test: /\.svg$/,
                use: [
                    {
                        loader: "babel-loader"
                    },
                    {
                        loader: "react-svg-loader",
                        options: {
                            jsx: true // true outputs JSX tags
                        }
                    }
                ]
            }
        ],
    },
    plugins: [
        new HtmlWebpackPlugin({
            template: path.join(__dirname, 'public', 'index.html')
        })
    ]
};