In this tutorial, you will create a microservice based on a common design pattern for processing high volumes of database requests with minimal lag in response times while also minimizing resource utilization in the underlying database engine.

This tutorial is meant for developers who are familiar with [Appsody](https://developer.ibm.com/blogs/introduction-to-appsody/) and experienced with the usage of [Java&trade; Database Connectivity](https://docs.oracle.com/javase/8/docs/technotes/guides/jdbc/) (JDBC) and the [Java Persistence API](https://docs.oracle.com/javaee/6/tutorial/doc/bnbpz.html) (JPA) programming model. 

Appsody is a core part of the development experience in the [IBM Cloud Pak for Applications](https://www.ibm.com/cloud/cloud-pak-for-applications) and is used in this tutorial as the basis for a common Java EE programming pattern, while adding the modern touch of a cloud-native microservice that can be easily transformed into a Kubernetes deployment.

For an even more relevant example, you will create this microservice using a JPA persistence context backed by a database connection pool, allowing the microservice endpoints to serve requests from the database with minimum latency and avoiding unnecessary resource strain on the remote database service.


## Prerequisites

This tutorial assumes that you have a robust understanding of Java programming. 

Complete the following steps to build and test applications on your local workstation:

* [Install Docker](https://docs.docker.com/get-started/)
  If using Windows or macOS, Docker Desktop is probably the best choice. If using a Linux system, [minikube](https://github.com/kubernetes/minikube) and its internal Docker registry is an alternative.

* [Install the Appsody CLI](https://appsody.dev/docs/getting-started/installation)

* [Install the IBM Cloud CLI](https://cloud.ibm.com/docs/cli)

* [Create an IBM Cloud API Key](https://cloud.ibm.com/iam/apikeys). The interface will look like this:
    
    ![Copy the API key](images/ibm-cloud-create-key.png)
    
    Once you click on the "Create" button, you will see the dialog with the resulting key. Copy the API key value from your own dialog and paste it somewhere safe. It will be used later to login via command-line interface and referenced as ${IBMCLOUD_API_KEY} throughout the instructions in this tutorial. 

* A running Kubernetes cluster

    This tutorial uses a cluster in the [IBM Cloud](https://cloud.ibm.com/), which is available in the free tier. However, you will need a credit card or promo code to use the [free Kubernetes cluster](https://cloud.ibm.com/docs/containers?topic=containers-getting-started). A Kubernetes lite cluster itself is free of charge, but it cannot be created in an IBM Cloud Lite account.


## Estimated time

With the prerequisites in place, you should be able to complete this tutorial in 1 hour.

## Steps

Following along to this tutorial, you will perform the following steps:

1. [Create the starter application](#step-1-create-the-starter-application)
1. [Modify the application](#step-2-modify-the-application)
1. [Modify the server runtime configuration](#step-3-modify-the-server-runtime-configuration)
1. [Create the DB2 Service](#step-4-create-the-db2-service)
1. [Configure cluster to access the database service](#step-5-configure-cluster-to-access-the-database-service)
1. [Deploy the application to the cluster](#step-6-deploy-the-application-to-the-cluster)
1. [(Optional) Run the application locally](#step-7-optional-run-the-application-locally)

At the end of the tutorial, you will have progressed from creating and containerizing an application to creating a DB2 service and deploying the resulting application to a Kubernetes cluster:

![Tutorial progress](images/application-jee-jpa-db2.png)


## Step 1. Create the starter application

Your first step is to create a new application based on the default application template of the [Java MicroProfile collection](https://github.com/kabanero-io/collections/tree/master/incubator/java-microprofile) available in the kabanero.io collection hub. 

1. Register the collection repository in `appsody` with the following command:

    ```
    appsody repo add kabanero https://github.com/kabanero-io/collections/releases/latest/download/kabanero-index.yaml
    ```

1. With the `kabanero` repository registered and assuming your local Docker instance is already up and running, create the directory for the new application and initialize the directory with the application template:

    ```sh
    mkdir jee-sample
    cd jee-sample
    appsody init kabanero/java-microprofile
    ```

Once the initialization step completes, your `jee-sample` folder should contain files matching a structure similar to the one below:

```
jee-sample/
├── .appsody-config.yaml
├── pom.xml
└── src/
    ├── main/
    |   ├── webapp/
    |   │   ├── index.html
    |   │   └── WEB-INF/
    |   |       └──beans.xml
    |   ├── java/
    |   |   └── dev/
    |   |       └── appsody/
    |   |           └── starter/
    |   |               ├── health/
    |   |               |   ├── StarterLivenessCheck.java
    |   |               |   └── StarterReadinessCheck.java
    |   |               └── StarterApplication.java
    |   └── liberty/
    |       └── config/
    |           └── server.xml
    └── test/
        └── java/
            └── it/
                └── dev/
                    └── appsody/
                        └── starter/
                            └── HealthEndpointTest.java
```

Note that the application template may evolve over time, so some of the files and directories may not match exactly the ones you see in the image above.

## Step 2. Modify the application

The next subsections cover changes you make to the Java source code and Maven `pom.xml` build file.

### Add JPA persistence unit

The application in this tutorial accesses the database through the JPA programming model, which means the application must have a persistence unit instructing the runtime about the location and structure of the database.

You will create the new JPA persistence unit in the location specified for applications packaged as a WAR file.

1. Create the directory `src/main/resources/META-INF` and then create the JPA `persistence.xml` file in that directory with the following contents:
 
```xml
<?xml version="1.0" encoding="UTF-8"?>
<persistence version="2.2"
    xmlns="http://xmlns.jcp.org/xml/ns/persistence"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/persistence
                        http://xmlns.jcp.org/xml/ns/persistence/persistence_2_2.xsd">
    <persistence-unit name="jee-sample" transaction-type="JTA">
        <jta-data-source>jdbc/sample</jta-data-source>
    </persistence-unit>
</persistence>
```

Notice the `jdbc/sample` JNDI name in the `jta-data-source` field, which is where the JPA persistence context expects to find the JDBC data source. You will define this data source in the server runtime configuration later in the tutorial, once you are done with the application changes.

### Create a generic JPA access object

With the JPA persistence unit `jee-sample` defined, you will create a Java data access object matching that persistence unit. The data access object is responsible for isolating the rest of the application from interactions with the persistence layer.

First, create a new `src/main/java/dev/appsody/jpa/dao` directory for the `dev.appsody.jpa.dao` Java package. Then, create a new Java class `GenericDao.java` with the following content:


```java
package dev.appsody.jpa.dao;

import java.util.List;

import javax.enterprise.context.Dependent;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;

@Dependent
public class GenericDao<T> {

    @PersistenceContext(name = "jee-sample")
    private EntityManager em;

    public void create(T resource) {
        em.persist(resource);
    }

    public T find(Class<T> clazz, String resourceId) {
        return em.find(clazz, resourceId);
    }

    public void updateDepartment(T resource) {
        em.merge(resource);
    }

    public void deleteDepartment(T resource) {
        em.remove(resource);
    }

    /**
     * 
     * Assumes all JPA entities in this application have a 
     * "findAll" named query.
     */
    public List<T> readAll(Class<T> clazz) {
        return em.createNamedQuery(clazz.getSimpleName() + ".findAll", clazz).getResultList();
    }
}
```

Notice how the `name` field in the `@PersistenceContext` annotation matches the name in the `persistence-unit` field of the `src/main/resources/META-INF/persistence.xml` file created in the previous step of this tutorial. 

### Create a model instance for the database table

With the data access class in place, you will create a JPA entity to represent a table named `Department` in the database. 

Create a new `src/main/java/dev/appsody/jpa/model` directory for the `dev.appsody.jpa.model` Java package. Then create a new Java class `Department.java` with the following content:

```java
package dev.appsody.jpa.model;

import java.io.Serializable;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.NamedQuery;

/**
 * The persistent class for the DEPARTMENT database table.
 */
@Entity
@NamedQuery(name="Department.findAll", query="SELECT d FROM Department d")
public class Department implements Serializable {
    private static final long serialVersionUID = 1L;
    private String deptno;
    private String deptname;
    private String location;

    public Department() {
    }

    public Department(String deptno, String deptname, String location) {
        super();
        this.deptno = deptno;
        this.deptname = deptname;
        this.location = location;
    }

    @Id
    public String getDeptno() {
        return this.deptno;
    }

    public void setDeptno(String deptno) {
        this.deptno = deptno;
    }

    public String getDeptname() {
        return this.deptname;
    }

    public void setDeptname(String deptname) {
        this.deptname = deptname;
    }

    public String getLocation() {
        return this.location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

}
```

Note that, later in this tutorial, you will create the database table `Department` to back this JPA entity.

### Create REST endpoints

At this point, you have the Java classes that can enable the application to retrieve rows from the `Department` table using JPA. So, the final class to complete the application contains REST endpoints to allow other applications to work with the persistence layer.

Create a new directory `src/main/java/dev/appsody/jpa/resources` package named `dev.appsody.jpa.resources`, containing a file named `DepartmentResource.java` with the contents below:

```java
package dev.appsody.jpa.resources;

import javax.enterprise.context.RequestScoped;
import javax.inject.Inject;
import javax.json.Json;
import javax.json.JsonArray;
import javax.json.JsonArrayBuilder;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;
import javax.transaction.Transactional;
import javax.ws.rs.Consumes;
import javax.ws.rs.DELETE;
import javax.ws.rs.FormParam;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import dev.appsody.jpa.dao.GenericDao;
import dev.appsody.jpa.model.Department;

@RequestScoped
@Path("departments")
public class DepartmentResource {

    @Inject
    private GenericDao<Department> dao;

    /**
     * Creates a new dept from the submitted data (name, time and
     * location) by the user.
     */
    @POST
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    @Transactional
    public Response addNewDepartment(@FormParam("name") String name, @FormParam("deptno") String deptno,
            @FormParam("location") String location) {
        Department newDepartment = new Department(name, deptno, location);
        if (dao.find(Department.class, deptno) != null) {
            return Response.status(Response.Status.BAD_REQUEST).entity("Department already exists").build();
        }
        dao.create(newDepartment);
        return Response.status(Response.Status.NO_CONTENT).build();
    }

    /**
     * Updates a dept with the submitted data (name, deptno and
     * location) by the user.
     */
    @PUT
    @Path("{deptno}")
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    @Transactional
    public Response updateDepartment(@FormParam("name") String name, @PathParam("deptno") String deptno,
            @FormParam("location") String location) {
        Department prevDepartment = dao.find(Department.class, deptno);
        if (prevDepartment == null) {
            return Response.status(Response.Status.NOT_FOUND).entity("Department does not exist").build();
        }
        prevDepartment.setDeptname(name);
        prevDepartment.setLocation(location);

        dao.updateDepartment(prevDepartment);
        return Response.status(Response.Status.NO_CONTENT).build();
    }

    /**
     * Deletes a specific existing/stored dept
     */
    @DELETE
    @Path("{deptno}")
    @Transactional
    public Response deleteDepartment(@PathParam("deptno") String deptNo) {
        Department dept = dao.find(Department.class, deptNo);
        if (dept == null) {
            return Response.status(Response.Status.NOT_FOUND).entity("Department does not exist").build();
        }
        dao.deleteDepartment(dept);
        return Response.status(Response.Status.NO_CONTENT).build();
    }

    /**
     * Returns a specific existing/stored dept
     */
    @GET
    @Path("{deptno}")
    @Produces(MediaType.APPLICATION_JSON)
    @Transactional
    public JsonObject getDepartment(@PathParam("deptno") String deptNo) {
        JsonObjectBuilder builder = Json.createObjectBuilder();
        Department dept = dao.find(Department.class, deptNo);
        if (dept != null) {
            builderAddDepartment(builder, dept);
        }
        return builder.build();
    }

    /**
     * Returns all existing/stored depts
     */
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Transactional
    public JsonArray getDepartments() {
        JsonObjectBuilder builder = Json.createObjectBuilder();
        JsonArrayBuilder finalArray = Json.createArrayBuilder();
        for (Department dept : dao.readAll(Department.class)) {
            builderAddDepartment(builder, dept);
            finalArray.add(builder.build());
        }
        return finalArray.build();
    }

    /**
     * Creates the JSON object for a department.
     */
    private void builderAddDepartment(JsonObjectBuilder builder, Department dept) {
        builderAddIfNotNull(builder, dept.getDeptno(), "deptNo");
        builderAddIfNotNull(builder, dept.getDeptname(), "name");
        builderAddIfNotNull(builder, dept.getLocation(), "location");
    }

    /**
     * Creates a fragment of the JSON object.
     */
    private void builderAddIfNotNull(JsonObjectBuilder builder, String v, String n) {
        if (v != null) {
            builder.add(n, v);
        }
    }
}
```

Notice that this class implements the REST endpoint `/depts` to retrieve data from the JPA `Department` entity.


### Access the connection pool via JNDI lookup

This Java class is not related to JPA data access, but it is a useful example to show how the microservice can access the database connections directly through a Java Naming and Directory Interface lookup.

Later in the tutorial, you bind the connection pool to a JNDI name in the server runtime, so the Java code can look up the Java Database Connectivity (JDBC) data source using that name.

Create a new Java class named `DatabaseResource.java` in the existing `src/main/java/dev/appsody/starter` directory. This class implements the REST endpoint `/database` accessing the JDBC data source through the `jdbc/sample` JNDI name.

The REST endpoint returns basic metadata extracted from a JDBC connection pulled out of the connection pool, which is the most basic validation that JDBC connections can be accessed in that way.

```java
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
```

### Add JDBC driver files to the application

At this point, you have all Java classes required to return JSON objects representing rows of a `Department` table in a remote database. Now it's time to make a final modification to the application: the inclusion of JDBC drivers into the final application package.

The DB2 JDBC driver files are available from [Maven central](https://mvnrepository.com/artifact/com.ibm.db2/jcc), so you will modify the application's `pom.xml` build file to include those files in the final application.

The download of dependencies is achieved with a `dependency` element inside the `dependencies` element of the `pom.xml` file located in the root directory of the application, so you need to place the following XML snippet inside the `dependencies` element: 

```xml
        <dependency>
            <groupId>com.ibm.db2</groupId>
            <artifactId>jcc</artifactId>
            <version>[11.1, 11.2)</version>
        </dependency>
```

Notice the usage of a range in the `version` field of the dependency, so that the build process automatically picks new patches of the driver for the 11.1 release while avoiding the inclusion of a new major version of the driver.


### Checkpoint for application changes 

You now have the application ready to use a JPA persistence unit named `jee-sample`, as well as a REST resource that can look up the JDBC data source using the JNDI name `jdbc/sample`.

The figure below indicates all new and modified files covered so far:

![Application changes](images/application-structure-2.png)


## Step 3. Modify the server runtime configuration

With all application changes completed, it is time to modify the server runtime configuration to define the JPA persistence unit and attach it to a data source bound to that JNDI name.


### Add a JPA feature

The template application does not include JPA support in the server runtime, which needs to be added for this application.

Add the JPA feature with the following XML snippet pasted into the `featureManager` element of the server runtime configuration, which is located in the `src/main/liberty/config/server.xml` file:

```xml
        <feature>jpa-2.2</feature>
```

### Bind your JDBC data source to the JDNI

You need to bind your JDBC data source to the `jdbc/sample` JNDI name referenced earlier in the JPA persistence unit. You can then change the bulid `pom.xml file to reference the DB2 JDBC drivers added to the application.

Add the following XML snippet to the `server` element in the `server.xml` runtime configuration file:

```xml
    <dataSource id="DefaultDataSource"
                jndiName="jdbc/sample"
                jdbcDriverRef="db2-driver"
                type="javax.sql.ConnectionPoolDataSource"
                transactional="true">

    </dataSource>
```

Notice how the `jndiName` field matches the `jta-data-source` field in the JPA persistence unit configuration file (`src/main/resources/META-INF/persistence.xml`) and how the `jdbcDriverRef` named "db2-driver" still needs to be defined.

### Map your JDBC driver and library to JAR files

The JDBC driver references a driver named `db2-driver`, which you need to map to the JAR files contained in the DB2 driver files. These DB2 driver files are included in the application via the `dependency` block in the `pom.xml` build file.

Create the [jdbcDriver](https://openliberty.io/docs/ref/config/#jdbcDriver.html) and associated `library` definitions by adding the following snippet to the `server.xml` file: 

```xml
    <jdbcDriver 
        id="db2-driver"
        javax.sql.ConnectionPoolDataSource="com.ibm.db2.jcc.DB2ConnectionPoolDataSource"
        libraryRef="db2-library"/>

    <library id="db2-library">
        <fileset 
            id="db2Fileset"
            dir="${server.config.dir}/resources"
            includes="jcc*.jar"/>
    </library>
```

Notice that the file pattern in the `includes` field matches the files contained in the DB2 JDBC driver version referenced earlier in the build `pom.xml` file.

### Connect to a database

You may have noticed that, so far, nothing in `server.xml` points to the database created earlier in the tutorial. These properties are added as a new `properties.db2.jcc` block inside the `dataSource` element in the `server.xml` configuration file.

The tutorial will show the full contents of the `server.xml` file at the end of this step, but for now, now how the `properties.db2.jcc` XML snippet should be placed inside the server configuration file:


```xml
    <dataSource id="DefaultDataSource"
                jndiName="jdbc/sample"
                jdbcDriverRef="db2-driver"
                type="javax.sql.ConnectionPoolDataSource"
                transactional="true">

        <properties.db2.jcc 
            serverName="${db_server}" 
            portNumber="${db_port}" 
            databaseName="${db_database}" 
            user="${db_user}" 
            password="${db_password}"
            sslConnection="true"/>
            
    </dataSource>
```

Notice the presence of configuration variables inside the new block, such as `${db_server}` and `${db_user}`. These variables are used here to avoid hard-coding the actual database parameters in the application code repository, which could lead to problems such as exposure of credentials in a code repository and brittle mapping of the application to a specific DB2 service instance.

These variables can be supplied to the application server in many different ways, as described [here](https://openliberty.io/docs/ref/config/serverConfiguration.html). You will provide their values later in the tutorial, when it covers the deployment aspects of the application.


### Configure a connection pool

As long as you are doing all the work to ensure the resulting microservice can leverage the performance advantages of using a JEE data source connection pool, you may also want to add connection pool settings from where the application developer can explore different settings to suit different loads.

These settings are documented in detail in the [connectionManager](https://openliberty.io/docs/ref/config/#dataSource.html#connectionManager) section of the Open Liberty documentation. 

Here is a working snippet that shows a sample of the `connectionManager` block placed within the `server.xml` file:  

```xml
    <dataSource id="DefaultDataSource"
                jndiName="jdbc/sample"
                jdbcDriverRef="db2-driver"
                type="javax.sql.ConnectionPoolDataSource"
                transactional="true">

       ...
            
      <connectionManager 
          connectionTimeout="180"
          maxPoolSize="10" 
          minPoolSize="1" 
          reapTime="180" 
          maxIdleTime="1800"
          agedTimeout="7200" 
          purgePolicy="EntirePool" />
    </dataSource>
```

As a last remark on the definition of the JDBC data source, the DB2 JDBC driver itself offers quite a bit of configuration settings, which are documented in detail in the [JDBC properties page](https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.apdv.java.doc/src/tpc/imjcc_r0052607.html) of the DB2 Knowledge Center.

This brings you to the final form of the `dataSource` block inside `server.xml`:  

```xml
    <dataSource id="DefaultDataSource"
                jndiName="jdbc/sample"
                jdbcDriverRef="db2-driver"
                type="javax.sql.ConnectionPoolDataSource"
                transactional="true">

	    <properties.db2.jcc 
		    serverName="${db_server}" 
		    portNumber="${db_port}" 
		    databaseName="${db_database}" 
		    user="${db_user}" 
		    password="${db_password}"
		    sslConnection="true"
		    currentLockTimeout="10"
		    cursorSensitivity="0"
		    deferPrepares="true"
		    driverType="4" 
		    loginTimeout="0" 
		    resultSetHoldability="1"
		    retrieveMessagesFromServerOnGetMessage="true"
		    traceLevel="-1"/>
            
        <connectionManager 
            connectionTimeout="180"
            maxPoolSize="10" 
            minPoolSize="1" 
            reapTime="180" 
            maxIdleTime="1800"
            agedTimeout="7200" 
            purgePolicy="EntirePool" />
    </dataSource>
```

This is also a good point to look at the entire `server.xml`(./src/main/liberty/config/server.xml) file accompanying this tutorial, to ensure your version matches the expected final contents.


### Adding JDBC driver files to the application package

In the previous sections, we outlined the definition of a `library` element in the `server.xml` configuration file, which instructs the server runtime to look for the JDBC driver files under the directory `${server.config.dir}/resources`.

Until Appsody Stack [issue #539](https://github.com/appsody/stacks/issues/539) is addressed, we need to resort to the  [Maven Resources Plugin](https://maven.apache.org/plugins/maven-resources-plugin/) to copy the JDBC driver files to a location where they will be found by Appsody when running the application locally and when building the final container for deployment.

Insert the XML snippet below inside the `plugins` element in the build `pom.xml` file: 

```xml
            <plugin>
                <artifactId>maven-resources-plugin</artifactId>
                <version>2.6</version>
                <executions>
                    <execution>
                        <id>copy-resources-appsody-build</id>
                        <phase>install</phase>
                        <goals>
                            <goal>copy-resources</goal>
                        </goals>
                        <configuration>
                            <outputDirectory>${basedir}/target/wlp/usr/servers/defaultServer/resources/</outputDirectory>
                            <resources>
                                <resource>
                                    <directory>${basedir}/target/${app.name}/WEB-INF/lib/</directory>
                                    <filtering>false</filtering>
                                    <includes>
                                        <include>jcc*.jar</include>
                                    </includes>
                                </resource>
                            </resources>
                        </configuration>
                    </execution>
                    <!-- Needed for the optional step later in the tutorial -->
                    <execution>
                        <id>copy-resources-appsody-run</id>
                        <phase>install</phase>
                        <goals>
                            <goal>copy-resources</goal>
                        </goals>
                        <configuration>
                            <outputDirectory>${basedir}/target/liberty/wlp/usr/servers/defaultServer/resources/</outputDirectory>
                            <resources>
                                <resource>
                                    <directory>${basedir}/target/${app.name}/WEB-INF/lib/</directory>
                                    <filtering>false</filtering>
                                    <includes>
                                        <include>jcc*.jar</include>
                                    </includes>
                                </resource>
                            </resources>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
```


### Trust remote database service certificate

Secure application design dictates that the application connecting to a remote database instance use encrypted network traffic to communicate with the database instance. In this tutorial, this means using the secure JDBC port in the DB2 service instance and also accepting the identity of the service instance.

The standard Java Microprofile collection in Kabanero.io currently does not trust any remote certificate. This restriction will change soon, when the underlying Open Liberty runtime adds [this feature](https://github.com/OpenLiberty/open-liberty/issues/9016) and that change is propagated to the Java MicroProfile collection.

In the meantime, you need to instruct Open Liberty to use a trust store for outbound connections. That trust store must contain either the certificate for the signing authority for the service certificate or the service certificate itself.

The trust store is then referenced in the server configuration file as an [SSL Repertoire](https://openliberty.io/docs/ref/config/ssl.html) element for outbound connections.

### Reference an existing CA database

Db2 On Cloud service instances, like the one used in this tutorial, are signed by a public certification authority that is already contained in the CA database shipped with the Java runtime used by the server.

The Open Liberty configuration [docs](https://openliberty.io/docs/ref/config/#sslDefault.html) explain in detail how to associate that CA database as the trust store for outbound secure communications, which involves changes to the server configuration.

Make those modifications to the `server.xml` configuration file adding the `keystore`, `ssl`, and `sslDefault` elements in the XML snippet below to the `server.xml` configuration file: 


```xml
<server description="Liberty server">
    ...

    <keyStore id="defaultTrustStore" 
        password="changeit"
        readOnly="false" 
        type="JKS" 
        location="${JAVA_HOME}/lib/security/cacerts">
    </keyStore>

    <ssl id="defaultSSLSettings" 
         keyStoreRef="defaultKeyStore"
         trustStoreRef="defaultTrustStore"></ssl>

    <sslDefault 
        sslRef="defaultSSLSettings" 
        outboundSSLRef="defaultSSLSettings"></sslDefault>

    ...
    
</server>
```

As an optional exercise to the reader, check the "Hostname verification on SSL configuration" section of this [blog entry](https://openliberty.io/blog/2019/06/21/microprofile-rest-client-19006.html) and make that modification to the `sslDefault` element in the above example.


### Checkpoint for server runtime changes 

All server configuration changes are ready to supply a functional JPA persistence unit to the appliction.

The figure below indicates all files modified in this sub-section of the tutorial:

![Server configuration changes](images/application-structure-3.png)

As an additional validation, specially due to the interative changes made to `server.xml`, you may want to look at the [resulting configuration file](src/main/liberty/config/server.xml).

## Step 4. Create the DB2 Service

[DB2 On Cloud](www.ibm.com/Db2/On-Cloud) resides in the IBM Cloud, so you need to [create an IBM Cloud account](https://cloud.ibm.com/registration) if you don't already have one. This tutorial uses a free instance of the free-tier plan, so there should be no cost to create a service instance.

All operations required this tutorial could be executed through the [user interface for DB2 on Cloud](https://cloud.ibm.com/catalog/services/db2)), but for brevity and precision, you will use command-line instructions for most steps.

First initialize the command-line interface (CLI) to communicate with the cluster in the IBM Cloud. This step assumes that you have already [created an IBM Cloud API Key](https://cloud.ibm.com/iam/apikeys) and exported its value to an environment variable named `IBMCLOUD_API_KEY`:

```
cluster_name=<put your cluster name here>
ibmcloud login --apikey ${IBMCLOUD_API_KEY}
eval $(ibmcloud ks cluster config --cluster ${cluster_name} --export)
```

### Create a DB2 database

Create a DB2 service instance named `sample-jee-db`, which will be referenced throughout the rest of this tutorial. Replace `us-south` in the instruction below with closest region to your cluster, amongst the regions supported by the service: 

| Name     | Display name |
|----------|--------------|
| au-syd   | Sydney       |
| eu-de    | Frankfurt    |
| eu-gb    | London       |
| us-south | Dallas       |

```sh
cloud_region=<put your region name here>

ibmcloud resource service-instance-create sample-jee-db  dashdb-for-transactions free ${cloud_region} -g default
```

The command produces output similar to this:

```
Creating service instance sample-jee-db in resource group default of account Username's Account as user@email...
OK
Service instance sample-jee-db was created.
                 
Name:         sample-jee-db   
ID:           crn:v1:... 
GUID:         ...   
Location:     ...   
State:        active   
Type:         service_instance   
...   
```

Any DB2 client, such as the application you are building, needs credentials to access the service instance. These credentials contain all attributes required to contact the service, such as hostname, port numbers, user, and password.

Type the following command to create a key named `sample-db-key` for the service:

```sh
ibmcloud resource service-key-create sample-db-key Administrator --instance-name sample-jee-db 
```

This command displays the status of the operation as well as the contents of the new key:

```
Creating service key of service instance sample-jee-db under account User Name's Account as user@email...

OK
Service key ... was created.
                  
Name:          sample-db-key   
State:         active   
Credentials:
               db:           BLUDB
               host:         dashdb-txn-...
               password:     ...
               port:         50000
               username:     ...
               ...

```

You can always reinspect the contents of the key with the following command:

```sh
ibmcloud resource service-key sample-db-key -g default --output json
```

### Populate the database

With the database and credential created, we want to create a new `DEPARTMENT` table with sample data rows in it.

We prepared a SQL file with the corresponding instructions, at
`src/test/resources/create-table.sql`, which you can use from any DB2 client connected to that database.

For convenience if you don't already have a DB2 client, you can use the "RUN SQL" panel from the Db2 On Cloud user interface, following these steps:

* Locate and click on the `sample-jee-db` service in the [Resources](https://cloud.ibm.com/resources) window.
    ![screenshot](images/db2-resource-panel.png)
* Select the **Manage** tab, then "Open Console" 
    ![screenshot](images/db2-manage-console.png)
* From the Console page, select **RUN SQL** from the menu activated from the upper-left icon
    ![screenshot](images/db-console-run.png)
* Click on **Blank** on the Choose the way to create tab and paste the content of `src/test/resources/create-table.sql` into the SQL editor
  ![copying into Blank space](images/db2-load-sql.png)
* Click **Run all** and wait for completion

Validate that the table was created and populated with contents by completing the following steps:

* Select **Explore -> Tables** from the menu activated from the upper-left icon
* Select the schema matching the user name for the credential created in earlier steps
* Select the "DEPARTMENT" table under the list of tables
    ![screenshot](images/db-department-table.png))
* Click on **View data** and verify that the table contains sample rows with data, similar to what is displayed in the figure below:
  ![figures in table](images/db-department-table-data.png)

## Step 5. Configure cluster to access the database service

This step makes the service credentials available to the cluster:

```
cluster_name=<name of your Kubernetes cluster>
ibmcloud ks cluster service bind --cluster ${cluster_name} --service sample-jee-db --key sample-db-key --role Administrator -n default
```

The credentials are created in a JSON structure inside a Kubernetes secret. The naming convention is: `binding-<name of the service instance>`, which in our case translates to `binding-sample-jee-db`.

Our sample application needs the secret to have the individual parameters of the credential as first-level items in the secret; whereas the Kubernetes secret created by the previous command is a JSON structure.

To map the JSON structure to the format expected by the application, first export the JSON object as a properties file:

```
kubectl get secret binding-sample-jee-db -o jsonpath='{.data.binding}' | base64 -D   | jq . | grep ":" |  tr -d " " | sed 's|":|=|g' | tr -d "\"" | tr -d "," | sed "s|port=50000|port=50001|g"> .db2.temp.env
```

The newly created `.db2.temp.env` file should have contents like this:

```properties
db=BLUDB
dsn=DATABASE=BLUDB;HOSTNAME=dashdb-txn...;PORT=50000;PROTOCOL=TCPIP;UID=...;PWD=...;
host=dashdb-txn...
hostname=dashdb-txn...
https_url=https://dashdb-txn...
jdbcurl=jdbc:db2://dashdb-txn...:50000/BLUDB
parameters={}
password=...
port=50001     << We replaced 50000 with 50001 because we want to use the DB2 SSL port
ssldsn=DATABASE=BLUDB;HOSTNAME=dashdb-txn-...;PORT=50001;PROTOCOL=TCPIP;UID=...;PWD=...;Security=SSL;
ssljdbcurl=jdbc:db2://dashdb-txn-...:50001/BLUDB:sslConnection=true;
uri=db2://...:...@dashdb-txn-...:50000/BLUDB
username=...
```

Notice how the previous command replaced port 50000 with port 50001, which is where the DB2 service instance listens for secure traffic.

Now you can create a new secret based on that properties file:

```sh
kubectl create secret generic sample-jee-db-secret --from-env-file=.db2.temp.env
```

You are not deleting the temporary `.db2.temp.env` file at this point because we want to use it later in the tutorial.

As a final validation, inspect the new key with the command below:

```sh
kubectl get secret sample-jee-db-secret -o json
```

You should see output resembling the output below:

```json
{
    "apiVersion": "v1",
    "data": {
        "db": "QkxVREI=",
        "host": ...,
        "password": ...,
        "port": "NTAwMDE=",
        "username": ...
    },
    ...
}
```

Notice how the connectivity parameters are arranged as top-level elements inside the `data` element. Each of these parameters will later be mapped to individual configuration variables in the container runtime.


## Step 6. Deploy the application to the cluster

With the changes made to the runtime `server.xml` configuration file, you have the runtime ready to supply a data source backed by a connection pool to the application, as well as an application that can use that data source as the basis for a JPA persistence unit.

As a recap of previous steps, you inserted a few configuration variables in the `server.xml` configuration file, which need to be mapped to the actual deployment file with the instructions in this section. These are the variables in `server.xml`:

```xml
        <properties.db2.jcc 
            serverName="${db_server}" 
            portNumber="${db_port}" 
            databaseName="${db_database}" 
            user="${db_user}" 
            password="${db_password}"
```

You also created a Kubernetes secret containing the credentials for the DB2 service instance:

```json
kubectl get secret sample-jee-db-secret -o json

{
    "apiVersion": "v1",
    "data": {
        "db": ...
        "host": ...
        "password": ...
        "port": 50001
        "username": ...
    },
    "kind": "Secret",
    ...
}
```

According to the [server configuration documentation](https://openliberty.io/docs/ref/config/serverConfiguration.html), these configuration variables are filled from different sources following an order of precedence. The server runtime first looks for them in one source and progresses to the next source if the value is not found in the preceding source.

One of these sources is an environment variable. In this tutorial, we use environment variables as the method for how the application will obtain the configuration from the Kubernetes pod running the application container.

Our deployment file for the cluster needs to map a key in the Kubernetes secret to the corresponding environment variable, which in turn will be used as the value for the matching configuration variable in the `server.xml` configuration file. This mapping requires the application developer to generate the Kubernetes deployment YAML file for the application and add environment mappings to it.

1. The first step is to generate the Kubernetes deployment YAML file, so you need to issue the following command:

    ```sh
    appsody build
    ```

    This command generates the Docker container image for deployment and also creates a new file named `app-deploy.yaml`, containing a minimal Kubernetes deployment file.

2. According to Appsody Operator documentation, if you add the following snippet under the `spec` element, you can map Kubernetes secrets to environment variables:

    ```yaml
    spec:
      ...
      env:
      - name: db_server
        valueFrom:
          secretKeyRef:
            key: host
            name: sample-jee-db-secret
      - name: db_port
        valueFrom:
          secretKeyRef:
            key: port
            name: sample-jee-db-secret
      - name: db_user
        valueFrom:
          secretKeyRef:
            key: username
            name: sample-jee-db-secret
      - name: db_password
        valueFrom:
          secretKeyRef:
            key: password
            name: sample-jee-db-secret
      - name: db_database
        valueFrom:
          secretKeyRef:
            key: db
            name: sample-jee-db-secret
    ```

    With all application modifications and configurations complete, you can now deploy the application to the remote cluster. 

    The image needs to be available on a Docker registry that is visible to the cluster. This tutorial uses Docker registry in the IBM Cloud, although it would also possible to use a public Docker registry such as the [Docker hub](https://hub.docker.com/) with additional configuration not covered in this tutorial.

1. As an initial step, log in to the IBM Cloud Container Registry and set the region that is closest to your cluster. Type the following commands:

    ```sh
    ibmcloud cr login
    ibmcloud cr region-set
    ```

1. The `region-set` command will prompt you for the registry region. Provide the answer and hit **Enter**:

    ```
    Choose a region
    1. ap-north ('jp.icr.io')
    2. ap-south ('au.icr.io')
    3. eu-central ('de.icr.io')
    4. global ('icr.io')
    5. uk-south ('uk.icr.io')
    6. us-south ('us.icr.io')
    Enter a number ()> 6
    The region is set to 'global', the registry is 'us.icr.io'.
    
    OK
    ```

    Notice the registry address for your choice of region (for example, `us.icr.io` in the above example), which needs to be referenced later in the name of the container image.

1. The next step is to create the [namespace](https://cloud.ibm.com/docs/containers?topic=containers-images#namespace) inside the container registry. This namesapce will contain the new image you are about to create:

    ```sh
    cr_namespace=<choose a unique name>
    ibmcloud cr namespace-add ${cr_namespace}
    ```

    And here is another critical change for the `app-deploy.yaml` file, due to the usage of the IBM Container Registry. By default, Appsody will create a new Kubernetes [service account named after the application](https://github.com/appsody/appsody-operator/blob/master/doc/user-guide.md#service-account) (`jee-sample` in the case of this tutorial), which does not have the `imagePullSecret` for the private registry.

1. Modify the deployment configuration to reuse the `default` service account in the cluster, which already has the `imagePullSecret` objects for all domains of the IBM Cloud Container Registry. If your cluster has a different account that you would rather use, you will need to manually add these secrets to that service account and use it in the instruction below instead of the string "`default`".

1. Add the following line to the `spec` element of `app-deploy.yaml`

    ```yaml
    spec:
      ...
      serviceAccountName: default
    ```

1. And finally, you can deploy the application with the following command:

```sh
registry_name=<domain for registry region, such as us.icr.io>
appsody deploy --push --tag ${registry_name}/${cr_namespace}/jee-sample
```

The `deploy` command may take a few minutes, largely due to the time it may take to transfer the image from your computer to the container registry.

Once deployment is completed, it may still take a few seconds until the cluster pod with the application is initialized. You can check the status of the pod with the command:

```sh
kubectl get pod -l app.kubernetes.io/name=jee-sample -w
```

Once the command output shows the pod status as `Running`, you can stop the command by pressing the `Ctrl+C` keys, then query the URL of the application with the following commands:


```sh
node_name=$(kubectl get pod -l app.kubernetes.io/name=jee-sample -o jsonpath='{.items[].spec.nodeName}')

public_ip=$(kubectl get node ${node_name} -o jsonpath='{.status.addresses[?(@.type=="ExternalIP")].address}')

public_port=$(kubectl get service jee-sample -o jsonpath='{.spec.ports[0].nodePort}')

echo "http://${public_ip}:${public_port}"
```

### Test the application

At this point in the tutorial, the application is running and ready to be accessed.

Just to anticipate the eventual debugging of common problems, open another command-line window and issue the following command to stream logs from the pod into the console window:

```sh
cluster_name=<put your cluster name here>
eval $(ibmcloud ks cluster config --cluster ${cluster_name} --export)

kubectl logs -f -l app.kubernetes.io/name=jee-sample
```

If at any point you realize there was something missing from previous instructions, make the changes to the application and deploy it again the `deploy` command again, specifying a different version of the image in each run, such as in the example below:

```sh
appsody deploy --push --tag ${registry_name}/${cr_namespace}/jee-sample:0.0.1
```

Type the following command from a different command-line prompt to test the `database` endpoint:

```sh
curl -s http://${public_ip}:${public_port}/starter/database
```

Remember this is the endpoint that uses a JNDI lookup to retrieve a connection from the connection pool. If everything is deployed correctly, you will see the the connection metadata in an output similar to the JSON structure below:

```json
{"client.info.ClientUser":"","client.info.ApplicationName":"","client.info.ClientHostname":"172.30.92.145","client.info.ClientAccountingInformation":"","db.product.name":"DB2/LINUXX8664","db.product.version":"SQL110144","db.major.version":11,"db.minor.version":1,"db.driver.version":"4.25.13","db.jdbc.major.version":4,"db.jdbc.minor.version":1}
```

The final test is to validate the `departments` endpoint:

```sh
curl -s http://${public_ip}:${public_port}/starter/departments
```

Once again, if everything is deployed correctly, you should see a JSON array containing the rows you inserted in the DB2 table earlier in the tutorial:

```json
[{"deptNo":"A00","name":"SPIFFY COMPUTER SERVICE DIV."},{"deptNo":"B01","name":"PLANNING"},{"deptNo":"C01","name":"INFORMATION CENTER"},{"deptNo":"D01","name":"DEVELOPMENT CENTER"},{"deptNo":"D11","name":"MANUFACTURING SYSTEMS"},{"deptNo":"D21","name":"ADMINISTRATION SYSTEMS"},{"deptNo":"E01","name":"SUPPORT SERVICES"},{"deptNo":"E11","name":"OPERATIONS"},{"deptNo":"E21","name":"SOFTWARE SUPPORT"},{"deptNo":"F22","name":"BRANCH OFFICE F2"},{"deptNo":"G22","name":"BRANCH OFFICE G2"},{"deptNo":"H22","name":"BRANCH OFFICE H2"},{"deptNo":"I22","name":"BRANCH OFFICE I2"},{"deptNo":"J22","name":"BRANCH OFFICE J2"}]
```

In fact, your new application should be able to field thousands of simultaneous requests to the database without strain, due to the connection pool keeping the expensive database connections open across different REST calls.

Type the following commands on the command-prompt:

```sh
for i in {0..2000} ; do curl -s http://${public_ip}:${public_port}/starter/departments  -o /dev/null & done
```

You can inspect the status of connections against the DB2 instance from the Db2 On Cloud user interface. Go back to the console for the DB2 instance and select **Monitor -> Collections** from the upper-left menu.

You should see a result similar to results below, where the connections from the application are highlighted to demonstrate that the connections are still held after the requests have been served:

![DB2 Connections Monitor](images/db-console-monitor.png)


## Step 7. (Optional) Run the application locally

You may have noticed how the deployment cycle takes a long time in comparison to the immediate response times expected in a typical coding session.

If you want to iterate over application changes, you will undoubtedly want some mechanism to test those changes locally.

Appsody supports local development with the `appsody run` command, so the only extra setup for the scenario in this tutorial is to inform the application of the connectivity parameters for the DB2 service instance.

You created a file named `.db2.temp.env` earlier in the tutorial, which contained the connectivity parameters for the DB2 instance. You may also recall that the property names in that file do not quite match the variable names in the `server.xml` runtime configuration file, so you need to change those names with the instructions below.

1. Type the following command to create a new `.db2.appsody.run.env` property file with property names matching the expected variable names:

    ```sh
    cat .db2.temp.env | sed "s/db=/db_database=/" | sed "s/host=/db_server=/" | sed "s/port=/db_port=/" | sed     "s/username=/db_user=/" | sed "s/password=/db_password=/" | grep db_ > .db2.appsody.run.env
    ```

1. Now, launch a local instance of the server with the following command:

    ```sh
    appsody run --docker-options="--env-file=.db2.appsody.run.env"
    ```

1. Once the application startup completes, you can test its output with the following commands from a different command-line prompt:

    ```sh
    curl -s localhost:9080/starter/database
    curl -s localhost:9080/starter/departments
    ```

    These commands produce the same output obtained from the previous step, where you deployed the application to the remote cluster:

    ```json
    {"client.info.ClientUser":"","client.info.ApplicationName":"","client.info.ClientHostname":"172.17.0.2","client.info.ClientAccountingInformation":"","db.product.name":"DB2/LINUXX8664","db.product.version":"SQL110144","db.major.version":11,"db.minor.version":1,"db.driver.version":"4.25.13","db.jdbc.major.version":4,"db.jdbc.minor.version":1}

    [{"deptNo":"A00","name":"SPIFFY COMPUTER SERVICE DIV."},{"deptNo":"B01","name":"PLANNING"},{"deptNo":"C01","name":"INFORMATION CENTER"},{"deptNo":"D01","name":"DEVELOPMENT CENTER"},{"deptNo":"D11","name":"MANUFACTURING SYSTEMS"},{"deptNo":"D21","name":"ADMINISTRATION SYSTEMS"},{"deptNo":"E01","name":"SUPPORT SERVICES"},{"deptNo":"E11","name":"OPERATIONS"},{"deptNo":"E21","name":"SOFTWARE SUPPORT"},{"deptNo":"F22","name":"BRANCH OFFICE F2"},{"deptNo":"G22","name":"BRANCH OFFICE G2"},{"deptNo":"H22","name":"BRANCH OFFICE H2"},{"deptNo":"I22","name":"BRANCH OFFICE I2"},{"deptNo":"J22","name":"BRANCH OFFICE J2"}]
    ```

1. Go back to the original command-line from where you started the application, press `Ctrl+C` in that command-line prompt, and wait for the application run to end. Then type the command below to ensure eventual lingering resources are cleaned up:

    ```sh
    appsody stop
    ```

### Tear down the installation

After you completed all the steps in this tutorial, you may choose to delete all artifacts created in your account. All commands in this subsection should be typed in the command-line prompt.

1. The first step is to delete the application in the cluster:

    ```sh
    appsody deploy delete
    ```

1. Delete the secret created for the application:

    ```sh
    kubectl delete secret sample-jee-db-secret
    ```

1. With the Appsody application deleted from the cluster, delete the namespace from the container registry, which also deletes all images inside the namespace:

    ```sh
     ibmcloud cr namespace-rm ${cr_namespace} -f
    ```

1. As a last step, unbind the DB2 service instance from the cluster and delete the service instance:

    ```sh
    ibmcloud ks cluster service unbind --cluster ${cluster_name} --service sample-jee-db --namespace default

    ibmcloud resource service-instance-delete sample-jee-db --recursive -f
    ```

You can now delete the entire directory for the application.

## Summary

After completing this tutorial, you should be able to use Appsody to convert an important class of existing Open Liberty or WebSphere Liberty applications into a cloud-native microservice. 

You should have enough references to adapt these techniques to use different database providers as well as generalize them to reuse other types of J2C-based resources, such as JMS connection pools.

## Next steps

Take the IBM Cloud Pak for Applications [product tour](https://www.ibm.com/cloud/garage/dte/producttour/deploy-ibm-cloud-pak-application-managed-openshift-ibm-cloud) and experience the entire deployment and development cycle against an actual OpenShift cluster.
