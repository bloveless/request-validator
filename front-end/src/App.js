import React from "react";
import {Route, Router, Switch} from "react-router-dom";
import {Container} from "reactstrap";

import Loading from "./components/Loading";
import NavBar from "./components/NavBar";
import Footer from "./components/Footer";
import Home from "./views/Home";
import Profile from "./views/Profile";
import ExternalApi from "./views/ExternalApi";
import {useAuth0} from "@auth0/auth0-react";
import history from "./utils/history";
import {fromCognitoIdentityPool} from "@aws-sdk/credential-providers";
import {DynamoDBClient, GetItemCommand} from "@aws-sdk/client-dynamodb";
import {GetCallerIdentityCommand, STSClient} from "@aws-sdk/client-sts";
import axios from "axios";


// styles
import "./App.css";

// fontawesome
import initFontAwesome from "./utils/initFontAwesome";
import aws4Interceptor from "./aws4Interceptor";

initFontAwesome();

const App = () => {
    const {isLoading, error, getIdTokenClaims} = useAuth0();

    if (error) {
        return <div>Oops... {error.message}</div>;
    }

    if (isLoading) {
        return <Loading/>;
    }

    getIdTokenClaims().then((token) => {
        if (token) {
            console.log('idToken', token);
            const credentials = fromCognitoIdentityPool({
                identityPoolId: "us-west-2:873773ee-0d22-4891-a90b-3221f5d1e517",
                customRoleArn: "arn:aws:iam::391324319136:role/cognito-admin-authenticated",
                logins: {
                    "dev-kjqsk80b2mpf2n3b.us.auth0.com": token.__raw,
                },
                clientConfig: {region: 'us-west-2'},
            })

            const dynamoClient = new DynamoDBClient({
                region: "us-west-2", credentials,
            })

            // Set the parameters
            const params = {
                TableName: "Stocks-a781d5cd", Key: {
                    PK: {S: "stockvalue#CDNS"}, SK: {S: "2023-01-27T18:00:00Z"},
                },
            };

            dynamoClient.send(new GetItemCommand(params)).then((item) => {
                console.log('dynamo item', item)
            }).catch((err) => {
                console.error('dynamo err', err);
            });

            const stsClient = new STSClient({
                region: "us-west-2", credentials,
            })

            stsClient.send(new GetCallerIdentityCommand({})).then((identity) => {
                console.log("identity", identity);
            }).catch((stsErr) => {
                console.error('stsErr', stsErr);
            });

            credentials().then((creds) => {
                const client = axios.create();
                const interceptor = new aws4Interceptor({
                    signingUrl: "https://gqpkz5upmj.execute-api.us-west-2.amazonaws.com",
                    // signingUrl: "https://api.brennonloveless.com",
                    service: 'execute-api',
                    region: 'us-west-2'
                }, {
                    accessKeyId: creds.accessKeyId,
                    secretAccessKey: creds.secretAccessKey,
                    sessionToken: creds.sessionToken,
                });

                client.interceptors.request.use(interceptor);
                let url = "https://api.brennonloveless.com";
                client.get(url).then((response) => {
                    console.log(response);
                    return response
                }).catch(function (error) {
                    console.error('api request err', error)
                });
            })
        }
    });

    return (<Router history={history}>
        <div id="app" className="d-flex flex-column h-100">
            <NavBar/>
            <Container className="flex-grow-1 mt-5">
                <Switch>
                    <Route path="/" exact component={Home}/>
                    <Route path="/profile" component={Profile}/>
                    <Route path="/external-api" component={ExternalApi}/>
                </Switch>
            </Container>
            <Footer/>
        </div>
    </Router>);
};

export default App;
