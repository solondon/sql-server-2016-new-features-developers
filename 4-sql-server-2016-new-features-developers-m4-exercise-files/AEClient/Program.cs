using System;
using System.Data;
using System.Data.SqlClient;

namespace AEClient
{
    class Program
    {
        static void Main(string[] args)
        {
            System.Diagnostics.Debugger.Break();

            Console.WriteLine("*** Without Encryption Setting ***");
            RunWithoutEncryptionSetting();

            Console.Clear();
            Console.WriteLine("*** With Encryption Setting ***");
            RunWithEncryptionSetting();

            Console.WriteLine("Press any key to continue");
            Console.ReadKey();
        }

        private static void RunWithoutEncryptionSetting()
        {
            const string ConnStr =
                "Data Source=.;Initial Catalog=MyEncryptedDB;Integrated Security=true;";

            using (var conn = new SqlConnection(ConnStr))
            {
                conn.Open();

                // Can query, but can't read encrypted data returned by the query
                using (var cmd = new SqlCommand("SELECT * FROM Customer", conn))
                {
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            var customerId = rdr["CustomerId"];
                            var name = rdr["Name"];
                            var ssn = rdr["SSN"];
                            var city = rdr["City"];

                            Console.WriteLine("CustomerId: {0}; Name: {1}; SSN: {2}; City: {3}", customerId, name, ssn, city);
                        }
                        rdr.Close();
                    }
                }

                // Can't query on Name
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Customer WHERE Name = @Name", conn))
                {
                    var parm = new SqlParameter("@Name", SqlDbType.VarChar, 20);
                    parm.Value = "John Smith";
                    cmd.Parameters.Add(parm);

                    try
                    {
                        cmd.ExecuteScalar();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Failed to run query on Name column");
                        Console.WriteLine(ex.Message);
                    }
                }

                // Can't query on SSN
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Customer WHERE SSN = @SSN", conn))
                {
                    var parm = new SqlParameter("@SSN", SqlDbType.VarChar, 20);
                    parm.Value = "n/a";
                    cmd.Parameters.Add(parm);

                    try
                    {
                        cmd.ExecuteScalar();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Failed to run query on SSN column");
                        Console.WriteLine(ex.Message);
                    }
                }

                // Can't insert encrypted data
                using (var cmd = new SqlCommand("INSERT INTO Customer VALUES(@Name, @SSN, @City)", conn))
                {
                    var nameParam = new SqlParameter("@Name", SqlDbType.VarChar, 20);
                    nameParam.Value = "Steven Jacobs";
                    cmd.Parameters.Add(nameParam);

                    var ssnParam = new SqlParameter("@SSN", SqlDbType.VarChar, 20);
                    ssnParam.Value = "333-22-4444";
                    cmd.Parameters.Add(ssnParam);

                    var cityParam = new SqlParameter("@City", SqlDbType.VarChar, 20);
                    cityParam.Value = "Los Angeles";
                    cmd.Parameters.Add(cityParam);

                    try
                    {
                        cmd.ExecuteNonQuery();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Failed to insert new row with encrypted data");
                        Console.WriteLine(ex.Message);
                    }
                }
                conn.Close();
            }

            Console.WriteLine();
        }

        private static void RunWithEncryptionSetting()
        {
            const string ConnStr =
                "Data Source=.;Initial Catalog=MyEncryptedDB;Integrated Security=true;" +
                "column encryption setting=enabled";

            using (var conn = new SqlConnection(ConnStr))
            {
                conn.Open();

                // Encrypted data gets decrypted after being returned by the query
                using (var cmd = new SqlCommand("SELECT * FROM Customer", conn))
                {
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            var customerId = rdr["CustomerId"];
                            var name = rdr["Name"];
                            var ssn = rdr["SSN"];
                            var city = rdr["City"];

                            Console.WriteLine("CustomerId: {0}; Name: {1}; SSN: {2}; City: {3}", customerId, name, ssn, city);
                        }
                        rdr.Close();
                    }
                }

                // Can't query on Name, even with column encryption setting, because it uses randomized encryption
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Customer WHERE Name = @Name", conn))
                {
                    var parm = new SqlParameter("@Name", SqlDbType.VarChar, 20);
                    parm.Value = "John Smith";
                    cmd.Parameters.Add(parm);

                    try
                    {
                        cmd.ExecuteScalar();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Failed to run query on Name column");
                        Console.WriteLine(ex.Message);
                    }
                }

                // Can query on SSN, because it uses deterministic encryption
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Customer WHERE SSN = @SSN", conn))
                {
                    var parm = new SqlParameter("@SSN", SqlDbType.VarChar, 20);
                    parm.Value = "n/a";
                    cmd.Parameters.Add(parm);

                    var result = (int)cmd.ExecuteScalar();
                    Console.WriteLine("SSN 'n/a' count = {0}", result);

                    // However, the search is not case sensitive, and won't match "N/A" with "n/a"
                    parm.Value = "N/A";
                    result = (int)cmd.ExecuteScalar();
                    Console.WriteLine("SSN 'N/A' count = {0}", result);
                }

                // Can never run a range query, even when using deterministic encryption
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Customer WHERE SSN >= @SSN", conn))
                {
                    var parm = new SqlParameter("@SSN", SqlDbType.VarChar, 20);
                    parm.Value = "500-000-0000";
                    cmd.Parameters.Add(parm);

                    try
                    {
                        cmd.ExecuteScalar();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Failed to run range query on SSN column");
                        Console.WriteLine(ex.Message);
                    }
                }

                // Can insert encrypted data
                using (var cmd = new SqlCommand("INSERT INTO Customer VALUES(@Name, @SSN, @City)", conn))
                {
                    var nameParam = new SqlParameter("@Name", SqlDbType.VarChar, 20);
                    nameParam.Value = "Steven Jacobs";
                    cmd.Parameters.Add(nameParam);

                    var ssnParam = new SqlParameter("@SSN", SqlDbType.VarChar, 20);
                    ssnParam.Value = "333-22-4444";
                    cmd.Parameters.Add(ssnParam);

                    var cityParam = new SqlParameter("@City", SqlDbType.VarChar, 20);
                    cityParam.Value = "Los Angeles";
                    cmd.Parameters.Add(cityParam);

                    cmd.ExecuteNonQuery();
                    Console.WriteLine("Successfully inserted new row with encrypted data");
                }
                conn.Close();
            }

            Console.WriteLine();
        }

    }
}
