/***************************************************************************
 * Copyright (c) 2009 Yahoo! Inc.  All rights reserved.
 *
 * The copyrights embodied in the content of this file are licensed by
 * Yahoo! Inc. under the BSD (revised) open source license.
 */

package com.yahoo.text;

import java.util.Locale;
import java.util.HashMap;

import java.io.IOException;
import java.text.ParseException;

import java.io.StringReader;

public class MessageFormatScannerTest
	extends junit.framework.TestCase
{
	private static Locale theLocale = new Locale("en", "US");

	String[][] theTestParameterPatterns =
	{
		{ "", "" },
		{ "a", "a" },
		{ "'a'", "'a'" },
		{ "{a}", "{0}" },
		{ "{a} {a}", "{0} {1}" },
		{ "{a} {b}", "{0} {1}" },
		{ "{a} '{b}'", "{0} '{b}'" },
		{ "{a} x {b} {x,y,z}", "{0} x {1} {2,y,z}" }
	};

	public void testParameters()
		throws	IOException,
				ParseException
	{
		for (int i=0; i<theTestParameterPatterns.length; i++)
		{
			StringReader reader    = new StringReader(theTestParameterPatterns[i][0]);
			MessageFormatScanner o = new MessageFormatScanner(reader);
			o.setLocale(theLocale);
			assertEquals(theTestParameterPatterns[i][1], o.parse());
		}
	}

	public void testParametersToArguments()
		throws	IOException,
				ParseException
	{
		Object o1 = new Integer(1);
		Object o2 = new Integer(2);

		StringReader reader    = new StringReader("{a}");
		MessageFormatScanner o = new MessageFormatScanner(reader);
		o.setLocale(theLocale);
		o.parse();

		Object[] args = o.getArguments(null, null);
		assertEquals(1, args.length);
		assertEquals("", args[0]);

		HashMap<String, Object> params = new HashMap<String, Object>();
		args = o.getArguments(params, null);
		assertEquals(1, args.length);
		assertEquals("", args[0]);

		params.clear();
		params.put("a", null);
		args = o.getArguments(params, null);
		assertEquals(1, args.length);
		assertEquals("", args[0]);

		params.clear();
		params.put("a", o1);
		args = o.getArguments(params, null);
		assertEquals(1, args.length);
		assertEquals(o1, args[0]);

		reader = new StringReader("{b} {a}");
		o      = new MessageFormatScanner(reader);
		o.setLocale(theLocale);
		o.parse();

		params.clear();
		params.put("a", o1);
		params.put("b", o2);
		args = o.getArguments(params, null);
		assertEquals(2, args.length);
		assertEquals(o2, args[0]);
		assertEquals(o1, args[1]);
	}

	String[][] theTestArgumentPatterns =
	{
		{ "", "" },
		{ "a", "a" },
		{ "'a'", "'a'" },
		{ "{0}", "{0}" },
		{ "{0} {0}", "{0} {0}" },
		{ "{0} {1}", "{0} {1}" },
		{ "{1} '{0}'", "{1} '{0}'" },
		{ "{0,x,y}", "{0,x,y}" }
	};

	public void testArguments()
		throws	IOException,
				ParseException
	{
		for (int i=0; i<theTestArgumentPatterns.length; i++)
		{
			StringReader reader    = new StringReader(theTestArgumentPatterns[i][0]);
			MessageFormatScanner o = new MessageFormatScanner(reader);
			o.setLocale(theLocale);
			o.setBuildParameterMap(false);
			assertEquals(theTestArgumentPatterns[i][1], o.parse());
		}
	}

	public class TestBean
	{
		private String s1;
		private String s2;
		private int    value;

		public TestBean(
			String	_s1,
			String	_s2,
			int		_value)
		{
			s1    = _s1;
			s2    = _s2;
			value = _value;
		}

		public String getS1()    { return s1; }
		public String getS2()    { return s2; }
		public int    getValue() { return value; }
	};

	public void testOGNL()
		throws	IOException,
				ParseException
	{
		StringReader reader    = new StringReader("{bean.s1} {bean.s2} ({bean.value}) {locale.language}");
		MessageFormatScanner o = new MessageFormatScanner(reader);
		o.setLocale(theLocale);
		o.parse();

		HashMap<String, Object> params = new HashMap<String, Object>();
		params.put("bean", new TestBean("abc", "xyz", 3));
		params.put("locale", theLocale);
		Object[] args = o.getArguments(params, null);
		assertEquals(4, args.length);
		assertEquals("abc", args[0]);
		assertEquals("xyz", args[1]);
		assertEquals(3, args[2]);
		assertEquals("en", args[3]);
	}


	public void testFormat()
		throws	IOException,
				ParseException
	{
		HashMap<String, Object> params = new HashMap<String, Object>();
		params.put("bean", new TestBean("abc", "xyz", 3));
		params.put("locale", theLocale);
		assertEquals("abc xyz (3) en", MessageFormatScanner.format("{bean.s1} {bean.s2} ({bean.value}) {locale.language}", params, theLocale));
	}
}
