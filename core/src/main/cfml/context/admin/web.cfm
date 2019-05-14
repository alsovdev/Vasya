<cfif structKeyExists(form, "captchaValue")>
	<cfset session.cap = form.captchaValue>
</cfif>
<cfsilent>
<cfparam name="request.disableFrame" default="false" type="boolean">
<cfparam name="request.setCFApplication" default="true" type="boolean">

<cfif request.setCFApplication>
	<cfapplication
		name="webadmin#server.lucee.version#"
		sessionmanagement="yes"
		clientmanagement="no"
		setclientcookies="yes"
		setdomaincookies="no"
		clientStorage="file"
		sessionStorage="memory"
		scriptprotect="all"
		sessiontimeout="#createTimeSpan(0,0,30,0)#"
		applicationtimeout="#createTimeSpan(1,0,0,0)#"
		localmode="update"
		webcharset="utf-8"
		>
</cfif>

<!--- todo: remember screenwidth, so images have the correct width etc. --->
<!--- PK: instead of session.screenWidth, we now have:
	application.adminfunctions.getdata('fullscreen')
	application.adminfunctions.getdata('contentwidth')
	If fullscreen==true, then you can use the contentwidth variable.
	Otherwise, use the regular content width.
--->

<cfif structKeyExists(url, 'enable')>
	<cfset session.enable = url.enable>
</cfif>
<cfparam name="session.alwaysNew" default="false" type="boolean">
<cfif structKeyExists(url, 'alwaysNew')>
	<cfset session.alwaysNew = url.alwaysNew == true>
</cfif>

<cfparam name="request.adminType" default="web">
<cfparam name="form.rememberMe" default="s">
<cfset ad = request.adminType>

<cfparam name="cookie.lucee_admin_lang" default="en">
<cfset session.lucee_admin_lang = cookie.lucee_admin_lang>

<cfset login_error = "">

<!--- Form --->
<cfif structKeyExists(form, "login_password" & request.adminType)>
	<cfadmin
		action="getLoginSettings"
		type="#request.adminType#"
		returnVariable="loginSettings">

	<cfset loginPause = loginSettings.delay>

	<cfif loginPause && structKeyExists(application, "lastTryToLogin") && isDate(application.lastTryToLogin) && DateDiff("s", application.lastTryToLogin, now()) LT loginPause>
		<cfset login_error = "Login disabled until #lsDateFormat(dateAdd("s", loginPause, application.lastTryToLogin))# #lsTimeFormat(dateAdd("s", loginPause, application.lastTryToLogin),'hh:mm:ss')#">
	<cfelse>
		<cfset application.lastTryToLogin = now()>
		<cfparam name="form.captcha" default="">

		<cfif loginSettings.captcha && structKeyExists(session, "cap") && compare(form.captcha,session.cap) NEQ 0>
			<cfset login_error = "Invalid security code (captcha) definition">
		<cfelse>
			<cfadmin
				action="hashPassword"
				type="#request.adminType#"
				pw="#form["login_password"&ad]#"
				returnVariable="hashedPassword">
			<cfset session["password" & request.adminType]=hashedPassword>
			<cfset session.lucee_admin_lang=form.lang>
			<!--- Thread operation for update provider --->
			<cfcookie expires="NEVER" name="lucee_admin_lang" value="#session.lucee_admin_lang#">
			<cfif form.rememberMe NEQ "s">
				<cfcookie
					expires="#dateAdd(form.rememberMe,1,now())#"
					name="lucee_admin_pw_#server.lucee.version#_#ad#"
					value="#hashedPassword#">
			<cfelse>
				<cfcookie expires="Now" name="lucee_admin_pw_#server.lucee.version#_#ad#" value="">
			</cfif>
			<cfif isDefined("cookie.lucee_admin_lastpage") && cookie.lucee_admin_lastpage neq "logout">
				<cfset url.action = cookie.lucee_admin_lastpage>
			</cfif>
		</cfif>
	</cfif>
</cfif>

<!--- Process New Password !--->
<cfif structKeyExists(form, "new_password") && structKeyExists(form, "new_password_re")>
	<cfif len(form.new_password) LT 6>
		<cfset login_error = "password is too short, it must have at least 6 chars">
	<cfelseif form.new_password NEQ form.new_password_re>
		<cfset login_error = "password and password retype are not equal">
	<cfelse>
		<cfadmin
			action="updatePassword"
			type="#request.adminType#"
			newPassword="#form.new_password#">
		<cfadmin
				action="hashPassword"
				type="#request.adminType#"
				pw="#form.new_password#"
				returnVariable="hashedPassword">
		<cfset session["password" & request.adminType]=hashedPassword>
		 <cfif form.rememberMe NEQ "s">
			<cfcookie
				expires="#dateAdd(form.rememberMe,1,now())#"
				name="lucee_admin_pw_#server.lucee.version#_#ad#"
				value="#hashedPassword#">
		<cfelse>
			<cfcookie expires="Now" name="lucee_admin_pw_#server.lucee.version#_#ad#" value="">
		</cfif>
	</cfif>
</cfif>

<!--- cookie ---->
<cfset fromCookie=false>
<cfif not structKeyExists(session, "password" & request.adminType) && structKeyExists(cookie,'lucee_admin_pw_#server.lucee.version#_#ad#')>
	<cfset fromCookie=true>
	<cftry>
		<cfset session["password"&ad]=cookie['lucee_admin_pw_#server.lucee.version#_#ad#']>
		<cfcatch></cfcatch>
	</cftry>
</cfif>

<!--- Session --->
<cfif structKeyExists(session, "password" & request.adminType)>
	<cftry>
		<cfadmin
			action="connect"
			type="#request.adminType#"
			password="#session["password" & request.adminType]#">
		<cfif request.adminType == "server">
			<cfadmin
			action="getDevelopMode"
			type="#request.adminType#"
			password="#session["password" & request.adminType]#"
			returnVariable="mode">
			<cfif mode.developMode>
				<cfset session.alwaysNew = true>
			</cfif>
		</cfif>

		 <cfcatch>
		 	<cfset login_error=cfcatch.message>
			<cfset structDelete(session, "password" & request.adminType)>
		</cfcatch>
	</cftry>
</cfif>

<cfif not structKeyExists(session,'lucee_admin_lang')>
	<cfset session.lucee_admin_lang ='en'>
</cfif>
</cfsilent>

<cfinclude template="resources/text.cfm">

<cfset request.self = request.adminType & ".cfm">
<!--- includes several functions --->
<cfinclude template="web_functions.cfm">
<cfif not structKeyExists(application, "adminfunctions") or (structKeyExists(session, "alwaysNew") && session.alwaysNew)>
	<cfset application.adminfunctions = new adminfunctions() />
</cfif>

<!--- Load Plugins --->
<cffunction name="loadPluginLanguage" output="false">
	<cfargument name="pluginDir">
	<cfargument name="pluginName">
	<cfargument name="lang" type="string" default="#session.lucee_admin_lang#">

	<cfset var fileLanguage="#pluginDir#/#pluginName#/language.xml">
	<cfif arguments.lang == "en">
		<cfset var language=struct(__action:'plugin',title:ucFirst(pluginName),text:'')>
	<cfelse>
		<cfset var language=loadPluginLanguage(arguments.pluginDir,arguments.pluginName,'en')>
	</cfif>
	<cfset var txtLanguage="">
	<cfset var xml="">

	<cfif fileExists(fileLanguage)>
		<cffile action="read" file="#fileLanguage#" variable="txtLanguage" charset="utf-8">
		<cfxml casesensitive="no" variable="xml"><cfoutput>#txtLanguage#</cfoutput></cfxml>
		<cfset language.__position=0>
		<cfif isDefined('xml.xmlRoot.XmlAttributes.action')>
			<cfset language.__action=trim(xml.xmlRoot.XmlAttributes.action)>
			<cfset language.__position=structKeyExists(xml.xmlRoot.XmlAttributes,"position")?xml.xmlRoot.XmlAttributes.position:0>
		</cfif>
		<cftry>
				<cfset xml = XmlSearch(xml, "/languages/language[@key='#lCase(trim(arguments.lang))#']")[1]>
			<cfcatch>
				<!--- fallback to english --->
				<cfset xml = XmlSearch(xml, "/languages/language[@key='en']")[1]>
			</cfcatch>
		</cftry>

		<cfset language.__group=structKeyExists(xml,"group")?xml.group.XmlText:UCFirst(language.__action)>
		<cfset language.title=xml.title.XmlText>
		<cfset language.text=xml.description.XmlText>
		<cfif isDefined('xml.custom')>
			<cftry><cfset var custom=xml.custom><cfcatch><cfdump var="#isDefined('xml.custoiihm')#"><cfdump var="#xml#" abort></cfcatch></cftry>
			<cfloop index="idx" from="1" to="#arraylen(custom)#">
				<cfset language[custom[idx].XmlAttributes.key]=custom[idx].XmlText>
			</cfloop>
		</cfif>
	</cfif>
	<cfreturn language>
</cffunction>


<cfset navigation = stText.MenuStruct[request.adminType]>


<cfset plugins=array()>
<cfif structKeyExists(session, "password" & request.adminType)>
	<cftry>
	<cfadmin
		action="getPluginDirectory"
		type="#request.adminType#"
		password="#session["password" & request.adminType]#"
		returnVariable="pluginDir">
	<cfset mappings['/lucee_plugin_directory/']=pluginDir>
	<cfapplication action="update" mappings="#mappings#">

	<cfset hasPlugin=false>
	<cfloop array="#navigation#" index="el">
		<cfif el.action == "plugin"><cfset hasPlugin=true></cfif>
	</cfloop>

	<cfif not hasPlugin or (structKeyExists(session, "alwaysNew") && session.alwaysNew)>
		<cfif not hasPlugin>
		<cfset plugin=struct(
			label:"Plugins",
			children:plugins,
			action:"plugin"
		)>
		<cfset navigation[arrayLen(navigation)+1]=plugin>
		</cfif>

		<cfset sctNav={}>
		<cfloop array="#navigation#" index="item">
			<cfset sctNav[item.action]=item>
		</cfloop>

		<cfdirectory directory="#plugindir#" action="list" name="plugindirs" recurse="no">
		<cfloop query="plugindirs">
			<cfif plugindirs.type == "dir">
				<cfset _lang=loadPluginLanguage(pluginDir,plugindirs.name)>
				<cfif isNull(_lang.__group)>
					<cfcontinue>
				</cfif>
				<cfset _act=_lang.__action>
				<cfset _group=_lang.__group>
				<cfset _pos=_lang.__position>
				<cfset structDelete(_lang,"__action",false)>

				<cfset application.pluginLanguage[session.lucee_admin_lang][plugindirs.name]=_lang>

				<cfset item=struct(
					label:_lang.title,
					action:plugindirs.name,
					_action:'plugin&plugin='&plugindirs.name
				)>

				<cfif not structKeyExists(sctNav,_act)>
					<cfset sctNav[_act]=struct(
						label:_group,
						children:[],
						action:_act
					)>
					<cfif _pos GT 0 && _pos LTE arrayLen(navigation)>
						<cfscript>
						for(i=arrayLen(navigation)+1;i>_pos;i--){
							navigation[i]=navigation[i-1];
						}
						navigation[_pos]=sctNav[_act];
						</cfscript>
					<cfelse>
						<cfset navigation[arrayLen(navigation)+1]=sctNav[_act]>
					</cfif>

				</cfif>

				<cfset children=sctNav[_act].children>
				<cfset isUpdate=false>
				<cfloop from="1" to="#arrayLen(children)#" index="i">
					<cfif children[i].action == item.action>
						<cfset children[i]=item>
						<cfset isUpdate=true>
			</cfif>
		</cfloop>
				<cfif not isUpdate>
					<cfset children[arrayLen(children)+1]=item>
	</cfif>

</cfif>
		</cfloop>
	</cfif>
		<cfcatch><cfrethrow></cfcatch>
	</cftry>

</cfif>
<cfsavecontent variable="arrow"><img src="resources/img/arrow.gif.cfm" width="4" height="7" /></cfsavecontent>
<cfif structKeyExists(url, "action") && url.action == "plugin" && not structKeyExists(url, "plugin")>
	<cflocation url="#request.self#" addtoken="no">
</cfif>
<cfif request.adminType == "web">

</cfif>

<cfscript>
	function isLuceneInstalled() {
		//if (!isNull(session._isLuceneInstalled)) return session._isLuceneInstalled;

		try {
			admin
				action="getRHServerExtensions"
				type="#request.adminType#"
				password="#session["password" & request.adminType]#"
				returnVariable="local.qry";

			var qry = qry.filter(function(row, rowNumber, qryData){
				return row.id=='EFDEB172-F52E-4D84-9CD1A1F561B3DFC8';
			});
			session._isLuceneInstalled=qry.recordCount>0;
			return qry.recordCount>0;

		}
		catch(e) {//systemOutput(e,1,1);
			return false;
		}
	}

	isRestrictedLevel = server.ColdFusion.ProductLevel == "community" or server.ColdFusion.ProductLevel == "professional";
	isRestricted = isRestrictedLevel && request.adminType == "server";

	// Navigation
	// As a Set of Array and Structures, so that it is sorted

	favoriteLis = "";

	context='';
	// write Naviagtion
	current.label="Overview";
	if (isDefined("url.action"))current.action=url.action;
	else current.action="overview";

	strNav ="";
	for(i=1;i lte arrayLen(navigation);i=i+1) {
		stNavi = navigation[i];
		hasChildren=structKeyExists(stNavi,"children");


		subNav="";
		hasActiveItem = false;
		if (hasChildren) {
			for(iCld=1; iCld lte ArrayLen(stNavi.children); iCld=iCld+1) {
				stCld = stNavi.children[iCld];
				isActive=current.action == stNavi.action & '.' & stCld.action or (current.action == 'plugin' && stCld.action == url.plugin);
				if (request.adminType == "web" && stCld.action == "search"){
					stCld.hidden=!isLuceneInstalled();
				}
				if (isActive) {
					hasActiveItem = true;
					current.label = stNavi.label & ' - ' & stCld.label;
				}

				if (not toBool(stCld,"hidden") && (not isRestricted or toBool(stCld,"display"))) {
					/*if (isActive) {
						sClass = "navsub_active";
					}
					else {
						sClass = "navsub";
					}*/
					if (structKeyExists(stCld,'_action'))_action=stCld._action;
					else _action=stNavi.action & '.' & stCld.action;

					isfavorite = application.adminfunctions.isfavorite(_action);
					li = '<li' & (isfavorite ? ' class="favorite"':'') & '><a '&(isActive?'id="sprite" class="menu_active"':'class="menu_inactive"')&' href="' & request.self & '?action=' &ListCompact( _action,'.') & '"> ' & stCld.label & '</a></li>';
					if (isfavorite)
					{
						favoriteLis &= '<li class="favorite"><a href="#request.self#?action=#_action#">#stNavi.label# - #stCld.label#</a></li>';
					}
					subNav = subNav & li;
					//subNav = subNav & '<div class="navsub">'&arrow&'<a class="#sClass#" href="' & request.self & '?action=' & _action & '"> ' & stCld.label & '</a></div>';
				}
			}
		}
		strNav = strNav &'';
		hasChildren=hasChildren and len(subNav) GT 0;
		if (not hasChildren) {
			if (toBool(stNavi,"display"))strNav = strNav & '<li><a href="' & request.self & '?action=' & stNavi.action & '">' & stNavi.label & '</a></li>';
			//if (toBool(stNavi,"display"))strNav = strNav & '<div class="navtop"><a class="navtop" href="' & request.self & '?action=' & stNavi.action & '">' & stNavi.label & '</a></div>';
		}
		else {
			idName = toIDField(stNavi.label);
			isCollapsed = not hasActiveItem and application.adminfunctions.getdata('collapsed_' & idName) == 1;
			strNav = strNav & '<li id="#idName#"#isCollapsed ? ' class="collapsed"':''#><a href="##">' & stNavi.label & '</a><ul#isCollapsed ? ' style="display:none"':''#>'&subNav& "</ul></li>";
			//strNav = strNav & '<div class="navtop">' & stNavi.label & '</div>'&subNav& "";
		}
		//strNav = strNav ;
	}
	strNav ='<ul id="menu">'& strNav&'</ul>' ;

/* moved to title in content area
	if (favoriteLis neq "")
	{
		strNav = '<li id="favorites"><a href="##">Favorites</a><ul>' & favoriteLis & "</ul></li>" & strNav;
	}
	*/

	function toBool(sct,key) {
		if (not structKeyExists(arguments.sct,arguments.key)) return false;
		return arguments.sct[arguments.key];
	}
	function getRemoteClients() {
		if (not isDefined("form._securtyKeys")) return array();
		return form._securtyKeys;
	}
	function toIDField(value)
	{
		return "nav_" & rereplace(arguments.value, "[^0-9a-zA-Z]", "_", "all");
	}
	request.getRemoteClients=getRemoteClients;
</cfscript>

<cfif not structKeyExists(session, "password" & request.adminType)>
		<cfadmin
			action="hasPassword"
			type="#request.adminType#"
			returnVariable="hasPassword">
	<cfif hasPassword>
		<cfmodule template="admin_layout.cfm" width="480" title="Login" onload="doFocus()">
			<cfif login_error NEQ ""><span class="CheckError"><cfoutput>#login_error#</cfoutput></span><br></cfif>
			<cfinclude template="login.cfm">
		</cfmodule>
	<cfelse>
		<cfmodule template="admin_layout.cfm" width="480" title="New Password">
			<cfif login_error NEQ ""><span class="CheckError"><cfoutput>#login_error#</cfoutput></span><br></cfif>
			<cfinclude template="login.new.cfm">
		</cfmodule>
	</cfif>
<cfelse>
	<cfsavecontent variable="content">
		<cfif not FindOneOf("\/",current.action)>
			<cfinclude template="#current.action#.cfm">
		<cfelse>
			<cfset current.label="Error">
			invalid action definition
		</cfif>
	</cfsavecontent>

	<cfif request.disableFrame>
		<cfoutput>#content#</cfoutput>
	<cfelse>
		<cfhtmlbody>
			<script type="text/javascript">
				$(function() {
					initMenu();
					__blockUI=function() {
						setTimeout(createWaitBlockUI(<cfoutput>"#JSStringFormat(stText.general.wait)#"</cfoutput>),1000);
					}
					$('.submit,.menu_inactive,.menu_active').click(__blockUI);
				});
				$("input[type='submit']").on("click", function(){
					if ($('span').hasClass( "commentError" )){
						$("span.commentError").each(function () {
							$(this).remove();
						});
					}
				});
			</script>
		</cfhtmlbody>

		<cfoutput>#strNav#</cfoutput>

		<cfmodule template="admin_layout.cfm" width="960" navigation="#strNav#" right="#context#" title="#current.label#" favorites="#favoriteLis#">
			<cfoutput>#content#</cfoutput>
		</cfmodule>
	</cfif>
</cfif>
<cfif current.action neq "overview">
	<cfcookie name="lucee_admin_lastpage" value="#current.action#" expires="NEVER">
</cfif>


<!--- <cftry>
<cfscript>
if (request.adminType == 'server'){
	include "services.update.functions.cfm";
	ud=getUpdateData();
	if (isNull(application.UpdateProvider[ud.location])) {
		thread name="providers" action="run" location=ud.location {
			application.UpdateProvider[ud.location]=getAvailableVersion();
			systemOutput("done!",1,1);
		}
	}
}
</cfscript>
<cfcatch></cfcatch>
</cftry> --->