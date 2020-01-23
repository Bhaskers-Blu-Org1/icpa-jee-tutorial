package dev.appsody.starter;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.SQLException;
import java.text.MessageFormat;

import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.sql.DataSource;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("/database")
public class DatabaseResource {

	private static final String JDBC_JNDI_CONTEXT = "jdbc/sample";

	/**
	 * REST endpoint for internal database metadata for the application connection.
	 */
	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public JsonObject databaseMetadata() {

		try {
			DataSource ds = InitialContext.doLookup(JDBC_JNDI_CONTEXT);

			JsonObjectBuilder response = buildConnectionMetadataResponse(ds);
			return response.build();
		} catch (NamingException e) {
			String errMsg = MessageFormat.format("Unable to locate connection pool in [{0}] due to {1}",
					JDBC_JNDI_CONTEXT, e.getMessage());
			throw new RuntimeException(errMsg, e);
		}
	}

	/**
	 * Builds a JSON array with the database metadata.
	 */
	private JsonObjectBuilder buildConnectionMetadataResponse(DataSource ds) {
		JsonObjectBuilder builder = Json.createObjectBuilder();

		try (Connection dbConn = ds.getConnection()) {
			dbConn.getClientInfo().entrySet().stream()
					.sorted((e1, e2) -> ((String) e1.getKey()).compareTo((String) e2.getValue()))
					.forEach(entry -> builder.add("client.info." + (String) entry.getKey(), (String) entry.getValue()));
			DatabaseMetaData metaData = dbConn.getMetaData();
			builder.add("db.product.name", metaData.getDatabaseProductName());
			builder.add("db.product.version", metaData.getDatabaseProductVersion());
			builder.add("db.major.version", metaData.getDatabaseMajorVersion());
			builder.add("db.minor.version", metaData.getDatabaseMinorVersion());
			builder.add("db.driver.version", metaData.getDriverVersion());
			builder.add("db.jdbc.major.version", metaData.getJDBCMajorVersion());
			builder.add("db.jdbc.minor.version", metaData.getJDBCMinorVersion());
		} catch (SQLException e) {
			String errMsg = MessageFormat
					.format("Unable to obtain connection metadata from connection pool retrived from "
							+ "context [{0}] due to {1}", JDBC_JNDI_CONTEXT, e.getMessage());
			throw new RuntimeException(errMsg, e);
		}
		return builder;
	}

}