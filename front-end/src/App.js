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
import {STSClient, GetCallerIdentityCommand} from "@aws-sdk/client-sts";

// styles
import "./App.css";

// fontawesome
import initFontAwesome from "./utils/initFontAwesome";
import {caller} from "express";

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
        console.log('idToken', token)
        const stsClient = new STSClient({
            credentials: fromCognitoIdentityPool({
                identityPoolId: "us-west-2:873773ee-0d22-4891-a90b-3221f5d1e517",
                customRoleArn: "arn:aws:iam::391324319136:role/cognito-admin-authenticated",
                logins: {
                    "dev-kjqsk80b2mpf2n3b.us.auth0.com": String(token),
                },
            })
        })

        stsClient.send(new GetCallerIdentityCommand({})).then((callerIdentity) => {
            console.log('callerIdentity', callerIdentity);
        });
    });


    return (
        <Router history={history}>
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
        </Router>
    );
};

export default App;
