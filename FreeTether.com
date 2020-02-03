using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FaucetCollector.Script;
//css_inc RecaptchaUtilities
class Coinfaucets : FaucetScript
{

    public override FaucetSettings Settings { get {

            return new FaucetSettings ( "about:blank" )
            {
                new FaucetSetting(){Name="User",Display="Email",Type=EditorType.TextBox,Required=true},
                new FaucetSetting(){Name="Pass",Display="Password",Type=EditorType.Password,Required=true},
                new FaucetSetting(){Name="Faucet",Display="Faucet Selected",Type=EditorType.ComboBox,Items=Faucets.Keys.ToList()}
            };
        }
    }

    public Dictionary<string , string> Faucets=new Dictionary<string, string>()
    {
        {"Tether USD" ,"https://freetether.com/"}
    };

    public string Url_
    {
        get
        {
            var Key=KeySelected;
            if ( Faucets.ContainsKey ( Key ) )
            {

                return Faucets[Key];
            }

            return Faucets.Values.FirstOrDefault ( );

        }
    }

    public string FaucetUrl
    {
        get
        {
            return Url_+"free";
        }
    }

    public string KeySelected
    {
        get
        {
            var Key=GetSetting("Faucet");
            if ( Faucets.ContainsKey ( Key ) )
            {

                return Key;
            }

            return Faucets.Keys.FirstOrDefault ( );
        }
    }
    public override void Start ( )
    {
        Title=KeySelected;
        SuccessXPath="//div[@class='result']";
        FailXPath="//div[@class='error']";
        base.Start ( );
        Url=Url_;



    }
    public override int BeforeLogin ( )
    {
        GoToUrl ( Url_ );
        Wait ( 2 );

        return base.BeforeLogin ( );

    }
    public override int DoLogin ( )
    {
       
        var UserBox=ElementByXPath("//div[@class='login-wrapper wrapper bg-1']//input[@placeholder='Email Address']");
        if ( !IsVisible(UserBox) )
        {
            return Fail ( "Userbox not visible" );
        }


        var PasswordBox=ElementByXPath("//div[@class='login-wrapper wrapper bg-1']//input[@placeholder='Password']");
        if ( !IsVisible(PasswordBox) )
        {
            return Fail ( "Password box not visible" );
        }

        var Loginbtn=ElementByXPath("//button[@class='main-button main-button-yellow login bg-3']");
        if ( !IsVisible(Loginbtn) )
        {
            return Fail ( "Login button not visible" );
        }

        SetText ( UserBox , GetSetting ( "User" ) );
        SetText ( PasswordBox , GetPassword ( "Pass" ) );


        Click ( Loginbtn );




        return base.DoLogin ( );    
    }

    public override bool IsLoggedIn ( )
    {
        return ElementByXPath ( "//a[@href='/logout']" )!=null;
    }

    public override int DoSolveFaucet ( )
    {
        GoToUrl ( FaucetUrl );
        Wait ( 2 );

        var ClaimBtn=ElementByXPath("//button[@class='main-button-2 roll-button bg-2']");

        if ( !IsVisible ( ClaimBtn ) )
        {
            return Fail ( "Claim btn is not visible" );
        }

        DoSolveCaptcha();


        if ( IsVisible ( ClaimBtn ) )
        {
            Click ( ClaimBtn );
        }

        return base.DoSolveFaucet ( );
    }
    public override int GetFaucetWaitTime ( )
    {
        var Timers=ElementsByXPath("//div[@class='digits']").Where(x=>IsVisible(x)).ToList();
        //visible
        if ( Timers.Count==2 )
        {
            int M,S;

            if ( int.TryParse ( Timers[0].Text , out M )&&int.TryParse ( Timers[1].Text , out S ) )
            {
                return M*60+S;
            }
        }

        return base.GetFaucetWaitTime ( );
    }
    public override int DoSolveCaptcha ( )
    {
        var result=base.DoSolveCaptcha ( );
        if ( result>0 )
        {
            return result;
        }
        RecaptchaUtility utility=new RecaptchaUtility(this);
        utility.DoSolve ( );

        return result;
    }
}

