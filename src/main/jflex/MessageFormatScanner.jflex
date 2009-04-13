/***************************************************************************
 * This scanner deconstructs a java.text.MessageFormat pattern that
 * contains named arguments and builds a true MessageFormat pattern and an
 * array of argument names, so a Map of arguments can be converted into an
 * array.  Named arguments can be repeated, so an input argument may
 * translate into multiple output arguments.  OGNL notation is allowed, as
 * long as the expression starts with the name of the key into the argument
 * map followed by a period (.)
 * 
 * Additonal format types are also supported:
 *  * string:     force conversion to String
 *  * html:       cook parameter, if it is a String
 *  * htmlstring: force conversion to String, and then cook
 *
 * It also provides the ability to specify a default FormatStyle for each
 * FormatType recognized by java.text.MessageFormat.
 *
 * Since default FormatStyles are useful even with indexed patterns, there
 * is the option to not build a parameter map, so indexed patterns will be
 * left alone except for inserting default FormatStyles.
 *
 * Invalid patterns generate a ParseException.
 *
 * Copyright (c) 2009 Yahoo! Inc.  All rights reserved.
 *
 * The copyrights embodied in the content of this file are licensed by
 * Yahoo! Inc. under the BSD (revised) open source license.
 */

package com.yahoo.text;

import java.util.Locale;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;

import java.text.MessageFormat;
import java.text.ParseException;

import java.io.StringReader;
import java.io.IOException;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.lang.StringEscapeUtils;
%%

%public
%class MessageFormatScanner
%unicode
%switch

/*
%ctorarg Locale locale
%init{
	itsLocale = locale;
%init}
*/

%x FORMAT_NAME FORMAT_TYPE FORMAT_STYLE DEFAULT_VALUE
%x QUOTED_STRING DV_QUOTED_STRING

%{
	private Locale				itsLocale;
	private boolean				itsBuildMapFlag  = true;
	private StringBuilder		itsPattern       = new StringBuilder();
	private ArrayList<String>	itsIndexNames    = new ArrayList<String>();
	private ArrayList<String>	itsIndexFormats  = new ArrayList<String>();
	private ArrayList<String>	itsIndexDefaults = new ArrayList<String>();
	private int					itsBraceDepth;
	private String				itsLastFormatType;
	private StringBuilder		itsLastDefaultValue;

	// used when a parameter is not provided
	private static final String	MISSING = "[missing parameter: {0}]";

	// default FormatStyles
	private static Map<Locale, Map>		theDefaultFormatStyles = new HashMap<Locale, Map>();
	private static DefaultFormatHook	theDefaultFormatHook;

	// for splitting OGNL expression
	private static String theOGNLPattern;
%}

%function parse
%type String
%yylexthrow ParseException

%{
	static
	{
		// for now, we only support OGNL that starts with "name."

		StringBuilder s = new StringBuilder()
			.append("\\")
//			.append(PropertyUtils.INDEXED_DELIM)
//			.append("|\\")
//			.append(PropertyUtils.MAPPED_DELIM)
//			.append("|\\")
			.append(PropertyUtils.NESTED_DELIM);

		theOGNLPattern = s.toString();
	}

	public static String format(
		String				pattern,
		Map<String, Object>	parameters,
		Locale				locale)
		throws				IOException,
							ParseException
	{
		return format(pattern, parameters, locale, new Options(false, false));
	}

	public static String format(
		String							pattern,
		Map<String, Object>				parameters,
		Locale							locale,
		MessageFormatScanner.Options	options)
		throws							IOException,
										ParseException
	{
		StringReader reader          = new StringReader(pattern);
		MessageFormatScanner scanner = new MessageFormatScanner(reader);
		scanner.setLocale(locale);
		String formatPattern         = scanner.parse();
		MessageFormat format         = new MessageFormat(formatPattern, locale);
		Object[] arguments           = scanner.getArguments(parameters, options);
		return format.format(arguments);
	}

	public static String format(
		String		pattern,
		Object[]	arguments,
		Locale		locale)
		throws		IOException,
					ParseException
	{
		StringReader reader          = new StringReader(pattern);
		MessageFormatScanner scanner = new MessageFormatScanner(reader);
		scanner.setLocale(locale);
		scanner.setBuildParameterMap(false);
		String formatPattern         = scanner.parse();
		MessageFormat format         = new MessageFormat(formatPattern, locale);
		return format.format(arguments);
	}

	public static String getDefaultFormatStyle(
		String	formatType,
		Locale	locale)
	{
		synchronized (theDefaultFormatStyles)
		{
			Map<String, String> map = theDefaultFormatStyles.get(locale);
			String style            = (map != null ? map.get(formatType) : null);
			if (style == null && theDefaultFormatHook != null)
			{
				style = theDefaultFormatHook.getDefaultFormatStyle(formatType, locale);
				if (style == null)
				{
					style = "";		// don't invoke theDefaultFormatHook again
				}
				setDefaultFormatStyle(formatType, locale, style);
			}
			return (style == null || style.length() == 0 ? null : style);
		}
	}

	public static void setDefaultFormatStyle(
		String	formatType,
		Locale	locale,
		String	formatStyle)
	{
		synchronized (theDefaultFormatStyles)
		{
			Map<String, String> map = theDefaultFormatStyles.get(locale);
			if (map == null)
			{
				map = new HashMap<String, String>();
				theDefaultFormatStyles.put(locale, map);
			}
			map.put(formatType, formatStyle);
		}
	}

	public static interface DefaultFormatHook
	{
		public String getDefaultFormatStyle(
			String	formatType,
			Locale	locale);
	}

	public static void setDefaultFormatHook(
		DefaultFormatHook hook)
	{
		theDefaultFormatHook = hook;
		theDefaultFormatStyles.clear();
	}

	public static class Options
	{
		public boolean escapeParams = false;
		public boolean stringParams = false;

		public Options(
			boolean escapeParams,
			boolean stringParams)
		{
			this.escapeParams = escapeParams;
			this.stringParams = stringParams;
		}
	}

	public void setLocale(
		Locale locale)
	{
		itsLocale = locale;
	}

	public boolean getBuildParameterMap()
	{
		return itsBuildMapFlag;
	}

	public void setBuildParameterMap(
		boolean buildMap)
	{
		itsBuildMapFlag = buildMap;
	}

	public String getPattern()
	{
		return itsPattern.toString();
	}

	public Object[] getArguments(
		Map<String, Object> parameters,
		Options				options)
	{
		int count                   = itsIndexNames.size();
		ArrayList<Object> arguments = new ArrayList<Object>(count);

		int i = 0;
		for (String name : itsIndexNames)
		{
			Object arg = null;
			if (parameters != null)
			{
				arg = parameters.get(name);

				if (arg == null)	// try OGNL
				{
					String[] s = name.split(theOGNLPattern, 2);
					if (s.length == 2 && s[0].length() > 0 && s[1].length() > 0)
					{
						arg = parameters.get(s[0]);
						if (arg != null)
						{
							try
							{
								arg = PropertyUtils.getProperty(arg, s[1]);
							}
							catch (Exception ex)
							{
								arg = null;
							}
						}
					}
				}
			}

			if (arg != null)
			{
				String fmt = itsIndexFormats.get(i);
				if ((options != null && options.stringParams) ||
					"string".equals(fmt))
				{
					arg = arg.toString();
				}

				if ("htmlstring".equals(fmt) ||
					(arg instanceof java.lang.String &&
					 ((options != null && options.escapeParams) ||
					  "html".equals(fmt))))
				{
					arg = StringEscapeUtils.escapeHtml(arg.toString());
				}

				arguments.add(arg);
			}
			else
			{
				arguments.add(itsIndexDefaults.get(i));
//					MessageFormat.format(MISSING, new Object[] { name }));
			}

			i++;
		}

		return arguments.toArray();
	}
%}

%%

<YYINITIAL>{

[^'{]+ |
''     {
	itsPattern.append(yytext());
}

' {
	itsPattern.append(yytext());
	yypushState(QUOTED_STRING);
}

"{" {
	itsPattern.append(yytext());
	yybegin(FORMAT_NAME);
}

<<EOF>> {
	return getPattern();
}

}

<FORMAT_NAME>{

[^,#}]+ {
	if (itsBuildMapFlag)
	{
		itsPattern.append(itsIndexNames.size());
		itsIndexNames.add(yytext().trim());
		itsIndexFormats.add("");
		itsIndexDefaults.add("");
	}
	else
	{
		itsPattern.append(yytext());
	}
}

,(html|string|htmlstring)"}" {
	if (itsBuildMapFlag)
	{
		String s = yytext();
		itsIndexFormats.set(itsIndexFormats.size()-1, s.substring(1, s.length()-1));
	}
	itsPattern.append("}");
	yybegin(YYINITIAL);
}

, {
	itsPattern.append(yytext());
	itsLastFormatType = new String();
	yybegin(FORMAT_TYPE);
}

"#" {
	itsLastDefaultValue = new StringBuilder();
	itsBraceDepth       = 1;
	yybegin(DEFAULT_VALUE);
}

"}" {
	itsPattern.append(yytext());
	yybegin(YYINITIAL);
}

}

<FORMAT_TYPE>{

[^,}]+ {
	itsLastFormatType = yytext().trim();
	if (itsBuildMapFlag)
	{
		itsIndexFormats.set(itsIndexFormats.size()-1, itsLastFormatType);
	}
	itsPattern.append(yytext());
}

, {
	itsPattern.append(yytext());
	itsBraceDepth = 1;
	yybegin(FORMAT_STYLE);
}

"}" {
	if (itsLastFormatType.length() > 0)
	{
		String formatStyle = getDefaultFormatStyle(itsLastFormatType, itsLocale);
		if (formatStyle != null)
		{
			itsPattern.append(",");
			itsPattern.append(formatStyle);
		}
	}
	itsPattern.append(yytext());
	yybegin(YYINITIAL);
}

}

<FORMAT_STYLE>{

[A-Za-z0-9_]+"}" {
	String style       = itsLastFormatType + "," + yytext().substring(0, yytext().length()-1).trim();
	String formatStyle = getDefaultFormatStyle(style, itsLocale);
	if (formatStyle != null)
	{
		itsPattern.append(formatStyle);
		itsPattern.append("}");
	}
	else
	{
		itsPattern.append(yytext());
	}
	yybegin(YYINITIAL);
}

[^'{}]+ |
''      {
	itsPattern.append(yytext());
}

' {
	itsPattern.append(yytext());
	yypushState(QUOTED_STRING);
}

"{" {
	itsPattern.append(yytext());
	itsBraceDepth++;
}

"}" {
	itsPattern.append(yytext());
	itsBraceDepth--;
	if (itsBraceDepth == 0)
	{
		yybegin(YYINITIAL);
	}
}

}

<DEFAULT_VALUE>{

[^'{}]+ {
	itsLastDefaultValue.append(yytext());
}

'' {
	itsLastDefaultValue.append("'");
}

' {
	yypushState(DV_QUOTED_STRING);
}

"{" {
	itsLastDefaultValue.append(yytext());
	itsBraceDepth++;
}

"}" {
	itsBraceDepth--;
	if (itsBraceDepth == 0)
	{
		itsIndexDefaults.set(itsIndexDefaults.size()-1, itsLastDefaultValue.toString());
		itsPattern.append(yytext());
		yybegin(YYINITIAL);
	}
	else
	{
		itsLastDefaultValue.append(yytext());
	}
}

}

<QUOTED_STRING>{

[^']+ {
	itsPattern.append(yytext());
}

' {
	itsPattern.append(yytext());
	yypopState();
}

}

<DV_QUOTED_STRING>{

[^']+ {
	itsLastDefaultValue.append(yytext());
}

' {
	yypopState();
}

}

<FORMAT_NAME,FORMAT_TYPE,FORMAT_STYLE,DEFAULT_VALUE,QUOTED_STRING,DV_QUOTED_STRING><<EOF>> {
	throw new ParseException(itsPattern.toString(), itsPattern.length()-1);
}
